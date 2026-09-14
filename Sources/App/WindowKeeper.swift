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
    /// change settles. Keyed like the settling windows.
    private var beganWithMouseDown: Set<CFHashCode> = []
    /// Windows waiting for their change to settle, by the CF hash of the
    /// element: notifications carry fresh wrappers for the same window, and an
    /// element cannot ride into a task, so the task looks it up here instead.
    private var settling: [CFHashCode: AXUIElement] = [:]
    private var settleTasks: [CFHashCode: Task<Void, Never>] = [:]
    private var trustPoll: Task<Void, Never>?

    /// A zoom animates through several resize notifications a frame apart;
    /// only the final frame matters, and every millisecond of waiting is a
    /// millisecond the window sits under the dock.
    private static let settleDelay = Duration.milliseconds(40)
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
            Task { @MainActor in
                self.reconcile()
                self.observe()
            }
        }
    }

    /// Observers exist for exactly the running apps, and only while the
    /// setting is on and Accessibility is granted.
    private func reconcile() {
        guard settings.settings.keepWindowsClear else {
            removeAllObservers()
            trustPoll?.cancel()
            trustPoll = nil
            return
        }
        guard Accessibility.isTrusted else {
            removeAllObservers()
            pollForTrust()
            Log.workspace.info("Window keeper waiting for Accessibility")
            return
        }
        trustPoll?.cancel()
        trustPoll = nil

        let wanted = Set(apps.apps.map(\.processIdentifier))
        for pid in observers.keys where !wanted.contains(pid) {
            removeObserver(for: pid)
        }
        for pid in wanted where observers[pid] == nil {
            addObserver(for: pid)
        }
        Log.workspace.info("Window keeper watching \(self.observers.count, privacy: .public) app(s)")
    }

    /// The grant lands in System Settings while the setting is already on,
    /// so the keeper checks back until it can start.
    private func pollForTrust() {
        guard trustPoll == nil else { return }
        trustPoll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, Accessibility.isTrusted else { continue }
                self?.trustPoll = nil
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
        // The callback is nonisolated to the compiler and main-thread in
        // fact; the element crosses no thread, only the type checker's line.
        nonisolated(unsafe) let window = element
        MainActor.assumeIsolated {
            keeper.scheduleCheck(of: window)
        }
    }

    private func scheduleCheck(of element: AXUIElement) {
        let key = CFHash(element)
        if settling[key] == nil, NSEvent.pressedMouseButtons != 0 {
            beganWithMouseDown.insert(key)
        }
        settling[key] = element
        settleTasks[key]?.cancel()
        settleTasks[key] = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled, let self else { return }
            settleTasks[key] = nil
            let byHand = beganWithMouseDown.remove(key) != nil
            guard let window = settling.removeValue(forKey: key) else { return }
            if byHand {
                Log.workspace.info("Window changed by hand; left alone")
            } else {
                nudgeIfNeeded(window)
            }
        }
    }

    private func nudgeIfNeeded(_ element: AXUIElement) {
        guard AppWindows.isStandardWindow(element), !AppWindows.isFullScreen(element),
              let reported = AppWindows.frame(of: element) else {
            let what = AppWindows.describe(element)
            Log.workspace.info("Window changed but is not a standard, readable window: \(what, privacy: .public)")
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
            Log.workspace.info("Window changed and is already clear")
            return
        }

        let target = Coordinates.accessibilityRect(fromAppKit: cleared, primaryHeight: primaryHeight)
        AppWindows.set(frame: target, of: element)
        Log.workspace.info("Nudged a window clear of the dock")
    }
}
