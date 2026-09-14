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
    private let displays: DisplayRegistry
    private let coordinator: DockCoordinator

    private var observers: [pid_t: AXObserver] = [:]
    /// Apps that refused an observer because they were still starting up,
    /// with how many times they have been retried.
    private var startingUp: [pid_t: Int] = [:]
    /// Changes that began with the mouse down are the person's own drag or
    /// resize, and are left alone even if the button is up by the time the
    /// change settles.
    private var beganWithMouseDown: Set<pid_t> = []
    /// Apps whose windows are changing, waiting for the change to settle.
    private var settleTasks: [pid_t: Task<Void, Never>] = [:]
    private let trustPoll = TaskBox()

    /// A zoom animates through several resize notifications a frame apart;
    /// only the final frame matters, and every millisecond of waiting is a
    /// millisecond the window sits under the dock.
    private static let settleDelay = Duration.milliseconds(40)
    /// Some apps post one resize notification as an animation starts and
    /// none as it ends, so a second look follows once any animation is over.
    private static let secondLookDelay = Duration.milliseconds(360)
    private static let startupRetries = 5
    private static let smallestDocumentWindow = CGSize(width: 240, height: 160)

    init(settings: SettingsStore, apps: RunningAppsMonitor, displays: DisplayRegistry, coordinator: DockCoordinator) {
        self.settings = settings
        self.apps = apps
        self.displays = displays
        self.coordinator = coordinator
        reconcile()
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = settings.settings
            _ = apps.apps
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
            removeAllObservers()
            trustPoll.task = nil
            return
        }
        guard Accessibility.isTrusted else {
            removeAllObservers()
            pollForTrust()
            Log.workspace.info("Window keeper waiting for Accessibility")
            return
        }
        trustPoll.task = nil

        let wanted = Set(apps.apps.map(\.processIdentifier))
        for pid in observers.keys where !wanted.contains(pid) {
            removeObserver(for: pid)
        }
        startingUp = startingUp.filter { wanted.contains($0.key) }
        for pid in wanted where observers[pid] == nil {
            addObserver(for: pid)
        }
        Log.workspace.info("Window keeper watching \(self.observers.count, privacy: .public) app(s)")
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

    private func addObserver(for pid: pid_t) {
        var observer: AXObserver?
        let created = AXObserverCreate(pid, Self.windowChanged, &observer)
        guard created == .success, let observer else {
            let reason = created.rawValue
            Log.workspace.notice("No observer for pid \(pid, privacy: .public): \(reason, privacy: .public)")
            return
        }

        let application = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXWindowCreatedNotification, kAXWindowResizedNotification] {
            let added = AXObserverAddNotification(observer, application, name as CFString, refcon)
            guard added == .success else {
                // An app that has just launched has no Accessibility server
                // yet and answers "cannot complete". It will have one shortly.
                if added == .cannotComplete {
                    retryLater(pid)
                } else {
                    let reason = added.rawValue
                    Log.workspace.notice(
                        "pid \(pid, privacy: .public) refused \(name, privacy: .public): \(reason, privacy: .public)"
                    )
                }
                return
            }
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
        startingUp[pid] = nil
    }

    private func retryLater(_ pid: pid_t) {
        let attempts = startingUp[pid, default: 0] + 1
        guard attempts <= Self.startupRetries else {
            startingUp[pid] = nil
            Log.workspace.notice("pid \(pid, privacy: .public) never became observable")
            return
        }
        startingUp[pid] = attempts
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.reconcile()
        }
    }

    private func removeObserver(for pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func removeAllObservers() {
        for pid in observers.keys {
            removeObserver(for: pid)
        }
    }

    /// Runs on the main thread: the observer's source lives on the main run loop.
    private static let windowChanged: AXObserverCallback = { _, element, _, refcon in
        guard let refcon else { return }
        let keeper = Unmanaged<WindowKeeper>.fromOpaque(refcon).takeUnretainedValue()
        // The pid is in the element's token and needs no messaging, unlike
        // anything else about the element, which some apps (Chrome) hand over
        // already invalid.
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        MainActor.assumeIsolated {
            keeper.scheduleCheck(of: pid)
        }
    }

    /// After a change settles, every standard window of that app is judged
    /// afresh. A single notification can carry a stale element, and a zoom
    /// can move more than one window; the list is the truth either way.
    private func scheduleCheck(of pid: pid_t) {
        if settleTasks[pid] == nil, NSEvent.pressedMouseButtons != 0 {
            beganWithMouseDown.insert(pid)
        }
        settleTasks[pid]?.cancel()
        settleTasks[pid] = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled, let self else { return }
            settleTasks[pid] = nil
            if beganWithMouseDown.remove(pid) != nil {
                Log.workspace.info("Windows changed by hand; left alone")
                return
            }
            judgeWindows(of: pid)
            try? await Task.sleep(for: Self.secondLookDelay)
            guard !Task.isCancelled else { return }
            judgeWindows(of: pid)
        }
    }

    /// The window server's bounds are the truth; an app's own report is the
    /// fallback for a window the server cannot be asked about.
    private func judgeWindows(of pid: pid_t) {
        let onScreen = WindowServer.windowBounds(ofProcess: pid)
        for window in AppWindows.list(processIdentifier: pid) ?? [] where !window.isMinimized {
            let truth = PrivateSymbols.windowNumber(of: window.element).flatMap { onScreen[$0] }
            nudgeIfNeeded(window.element, onScreen: truth)
        }
    }

    private func nudgeIfNeeded(_ element: AXUIElement, onScreen: CGRect?) {
        guard AppWindows.isStandardWindow(element), !AppWindows.isFullScreen(element),
              let reported = onScreen ?? AppWindows.frame(of: element) else {
            let what = AppWindows.describe(element)
            Log.workspace.info("Window is not a standard, readable window: \(what, privacy: .private)")
            return
        }

        let primaryHeight = displays.primaryHeight
        let frame = Coordinates.appKitRect(fromAccessibility: reported, primaryHeight: primaryHeight)
        // Bubbles, tooltips and menus are windows to Accessibility too, and
        // anchored to something; moving one would be worse than leaving it.
        guard frame.width >= Self.smallestDocumentWindow.width,
              frame.height >= Self.smallestDocumentWindow.height else {
            Log.workspace.info("Window changed but is too small to be a document window; left alone")
            return
        }
        guard let reservation = coordinator.reservation(at: CGPoint(x: frame.midX, y: frame.midY)) else {
            Log.workspace.info("Window changed on a display with no claim")
            return
        }
        guard let cleared = WindowNudge.clearedFrame(
            window: frame, visibleFrame: reservation.visibleFrame, strip: reservation.strip, edge: reservation.edge
        ) else {
            let place = "\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))"
            let strip = "\(Int(reservation.strip.minX)),\(Int(reservation.strip.minY)) "
                + "\(Int(reservation.strip.width))x\(Int(reservation.strip.height))"
            Log.workspace.info("Window at \(place, privacy: .public) is clear of strip \(strip, privacy: .public)")
            return
        }

        let target = Coordinates.accessibilityRect(fromAppKit: cleared, primaryHeight: primaryHeight)
        if let refusal = AppWindows.set(frame: target, of: element) {
            Log.workspace.notice("An app refused the nudge: \(refusal.rawValue, privacy: .public)")
            return
        }
        Log.workspace.info("Nudged a window clear of the dock")
        verifyLater(element, expected: target)
    }

    /// An app can accept a frame and not apply it (iTerm2 echoes the request
    /// back through Accessibility while the window stays put), so the window
    /// server is asked shortly afterwards whether the move really happened.
    private func verifyLater(_ element: AXUIElement, expected: CGRect) {
        guard let number = PrivateSymbols.windowNumber(of: element) else { return }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard let actual = WindowServer.windowBounds(ofProcess: pid)[number] else { return }
            let took = abs(actual.width - expected.width) < 2 && abs(actual.height - expected.height) < 2
            let size = "\(Int(actual.width))x\(Int(actual.height)) "
                + "wanted \(Int(expected.width))x\(Int(expected.height))"
            if took {
                Log.workspace.info("The nudge took: \(size, privacy: .public)")
            } else {
                Log.workspace.notice("The nudge was accepted but not applied: \(size, privacy: .public)")
            }
        }
    }
}
