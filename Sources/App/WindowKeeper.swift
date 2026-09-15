import AppKit
import ApplicationServices

/// Keeps windows clear of the docks, the way the system Dock's reserved space
/// keeps them clear of it.
///
/// Watches every user-facing app for windows being created or resized (a
/// zoom is a resize) and, once the change has settled, moves any window that
/// landed in a dock's strip out of it. A change made while the mouse is down
/// is the person resizing or dragging the window, and they may put it under
/// the dock if they like, as they can with the system Dock. Needs
/// Accessibility; without it, or with the setting off, nothing is observed.
@MainActor
final class WindowKeeper {
    private let settings: SettingsStore
    private let apps: RunningAppsMonitor
    let displays: DisplayRegistry
    let coordinator: DockCoordinator

    private let observers = ObserverSources()
    /// Apps that refused an observer, with how often they have been asked.
    private var refusals: [pid_t: Int] = [:]
    /// One pending retry per refusing app, so retries never multiply.
    private var retries: [pid_t: Task<Void, Never>] = [:]
    /// Apps asked the full number of times, left alone until they relaunch.
    private var gaveUp: Set<pid_t> = []
    /// Changes that began with the mouse down are the person's own drag or
    /// resize, and are left alone even if the button is up by the time the
    /// change settles.
    private var beganWithMouseDown: Set<pid_t> = []
    /// Apps whose windows are changing, waiting for the change to settle.
    private var settling: [pid_t: Settle] = [:]
    private var settleGeneration = 0
    private let trustPoll = TaskBox()
    private let sweep = TaskBox()
    /// Reconcile runs on every settings change; the log line is worth
    /// having only when the set of watched apps actually changed.
    private var lastReportedCount = -1
    private var lastLayoutVersion = -1

    private struct Settle {
        let generation: Int
        let task: Task<Void, Never>
        /// The first look is done and the second is pending. A notification
        /// arriving now begins a new change, and whether the mouse is down
        /// for it matters again.
        var hasJudged = false
    }

    /// A zoom animates through several resize notifications a frame apart;
    /// only the final frame matters, and every millisecond of waiting is a
    /// millisecond the window sits under the dock.
    private static let settleDelay = Duration.milliseconds(40)
    /// Some apps post one resize notification as an animation starts and
    /// none as it ends, so a second look follows once any animation is over.
    private static let secondLookDelay = Duration.milliseconds(360)
    /// Asked again after 1, 2, 4 ... seconds, at most half a minute apart:
    /// an app still starting up answers within a few, a hung one costs one
    /// timed-out message per attempt, and after two minutes it is left alone.
    private static let retryLimit = 8

    init(settings: SettingsStore, apps: RunningAppsMonitor, displays: DisplayRegistry, coordinator: DockCoordinator) {
        self.settings = settings
        self.apps = apps
        self.displays = displays
        self.coordinator = coordinator
        reconcile()
        observe()
    }

    /// Any settings change re-checks the switch; the running apps decide the
    /// observers; the docks' claims on their displays decide when every
    /// window is judged afresh.
    private func observe() {
        withObservationTracking {
            _ = settings.settings.keepWindowsClear
            _ = apps.apps
            _ = coordinator.layout.version
        } onChange: {
            Task { @MainActor [weak self] in
                self?.reconcile()
                self?.observe()
            }
        }
    }

    /// Observers exist for exactly the running apps, and only while the
    /// setting is on and Accessibility is granted.
    private func reconcile() {
        guard settings.settings.keepWindowsClear else {
            disarm()
            trustPoll.task = nil
            return
        }
        guard Accessibility.isTrusted else {
            disarm()
            pollForTrust()
            Log.workspace.info("Window keeper waiting for Accessibility")
            return
        }
        trustPoll.task = nil
        AppWindows.installMessagingTimeout()

        let wanted = Set(apps.apps.map(\.processIdentifier))
        forget(appsNotIn: wanted)
        var joined = false
        for pid in wanted where observers.byProcess[pid] == nil && retries[pid] == nil && !gaveUp.contains(pid) {
            joined = addObserver(for: pid) || joined
        }
        if observers.byProcess.count != lastReportedCount {
            lastReportedCount = observers.byProcess.count
            Log.workspace.info("Window keeper watching \(self.observers.byProcess.count, privacy: .public) app(s)")
        }

        // A window already under a dock when the keeper arms, or when a dock
        // moves or grows, never posts a notification about it, and a window
        // that is already zoomed posts nothing when double-clicked again. So
        // every watched window is judged once whenever the docks' claims
        // change or an app joins. An app merely coming to the front is not
        // worth a pass over every window on the machine.
        let layoutChanged = coordinator.layout.version != lastLayoutVersion
        lastLayoutVersion = coordinator.layout.version
        if joined || layoutChanged {
            scheduleSweep()
        }
    }

    /// A moment after the changes stop, one copy of the window list serves
    /// every app.
    private func scheduleSweep() {
        sweep.task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            let onScreen = WindowServer.windowBoundsByProcess()
            for pid in observers.byProcess.keys {
                judgeWindows(of: pid, onScreen: onScreen[pid] ?? [:])
            }
        }
    }

    /// The grant lands in System Settings while the setting is already on,
    /// so the keeper checks back until it can start.
    private func pollForTrust() {
        guard trustPoll.task == nil else { return }
        trustPoll.task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, Accessibility.isTrusted else { continue }
                self?.reconcile()
                return
            }
        }
    }

    // MARK: Observers

    /// Whether the app is observed now. An app that has just launched has no
    /// Accessibility server yet and answers "cannot complete"; it is asked
    /// again later. Any other refusal is final until the app relaunches.
    private func addObserver(for pid: pid_t) -> Bool {
        var observer: AXObserver?
        let created = AXObserverCreate(pid, Self.windowChanged, &observer)
        guard created == .success, let observer else {
            gaveUp.insert(pid)
            let reason = created.rawValue
            Log.workspace.notice("No observer for pid \(pid, privacy: .public): \(reason, privacy: .public)")
            return false
        }

        let application = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXWindowCreatedNotification, kAXWindowResizedNotification] {
            let added = AXObserverAddNotification(observer, application, name as CFString, refcon)
            guard added == .success else {
                if added == .cannotComplete {
                    retryLater(pid)
                } else {
                    gaveUp.insert(pid)
                    let reason = added.rawValue
                    Log.workspace.notice(
                        "pid \(pid, privacy: .public) refused \(name, privacy: .public): \(reason, privacy: .public)"
                    )
                }
                return false
            }
        }
        // Common modes, so a window changing while a menu is tracking is
        // heard then rather than in a burst once the menu closes.
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers.byProcess[pid] = observer
        refusals[pid] = nil
        return true
    }

    private func retryLater(_ pid: pid_t) {
        let attempts = refusals[pid, default: 0] + 1
        refusals[pid] = attempts
        guard attempts <= Self.retryLimit else {
            refusals[pid] = nil
            gaveUp.insert(pid)
            Log.workspace.notice("pid \(pid, privacy: .public) never became observable")
            return
        }
        let delay = Duration.seconds(min(1 << (attempts - 1), 30))
        retries[pid] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            retries[pid] = nil
            let stillRunning = apps.apps.contains { $0.processIdentifier == pid }
            guard stillRunning, observers.byProcess[pid] == nil, addObserver(for: pid) else { return }
            // Its windows opened while nobody was listening.
            scheduleSweep()
        }
    }

    private func removeObserver(for pid: pid_t) {
        guard let observer = observers.byProcess.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    /// Everything known about apps that are gone, so nothing stays keyed by
    /// a pid the system may hand to the next process.
    private func forget(appsNotIn wanted: Set<pid_t>) {
        for pid in observers.byProcess.keys where !wanted.contains(pid) {
            removeObserver(for: pid)
        }
        for pid in retries.keys where !wanted.contains(pid) {
            retries[pid]?.cancel()
            retries[pid] = nil
        }
        for pid in settling.keys where !wanted.contains(pid) {
            settling[pid]?.task.cancel()
            settling[pid] = nil
        }
        refusals = refusals.filter { wanted.contains($0.key) }
        gaveUp.formIntersection(wanted)
        beganWithMouseDown.formIntersection(wanted)
    }

    private func disarm() {
        forget(appsNotIn: [])
        sweep.task = nil
    }

    /// Runs on the main thread: the observer's source lives on the main run loop.
    private static let windowChanged: AXObserverCallback = { _, element, _, refcon in
        guard let refcon else { return }
        let keeper = Unmanaged<WindowKeeper>.fromOpaque(refcon).takeUnretainedValue()
        // The pid is in the element's token and needs no messaging, unlike
        // anything else about the element, which some apps (Chrome) hand over
        // already invalid.
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid > 0 else { return }
        MainActor.assumeIsolated {
            keeper.scheduleCheck(of: pid)
        }
    }

    // MARK: Judging

    /// After a change settles, every standard window of that app is judged
    /// afresh, and once more after any animation. A notification arriving
    /// before the second look cancels the whole check, so a window the person
    /// has since taken hold of is not moved under them.
    private func scheduleCheck(of pid: pid_t) {
        let beginsChange = settling[pid].map(\.hasJudged) ?? true
        if beginsChange, NSEvent.pressedMouseButtons != 0 {
            beganWithMouseDown.insert(pid)
        }
        settling[pid]?.task.cancel()
        settleGeneration += 1
        let generation = settleGeneration
        let task = Task { [weak self] in
            defer { self?.finishedSettling(pid, generation: generation) }
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled, let self else { return }
            if beganWithMouseDown.remove(pid) != nil {
                Log.workspace.info("Windows changed by hand; left alone")
                return
            }
            judgeWindows(of: pid)
            if settling[pid]?.generation == generation {
                settling[pid]?.hasJudged = true
            }
            try? await Task.sleep(for: Self.secondLookDelay)
            guard !Task.isCancelled else { return }
            judgeWindows(of: pid)
        }
        settling[pid] = Settle(generation: generation, task: task)
    }

    private func finishedSettling(_ pid: pid_t, generation: Int) {
        guard settling[pid]?.generation == generation else { return }
        settling[pid] = nil
    }
}
