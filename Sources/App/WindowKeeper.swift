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
    /// Windows waiting for their change to settle, by the CF hash of the
    /// element: notifications carry fresh wrappers for the same window, and an
    /// element cannot ride into a task, so the task looks it up here instead.
    private var settling: [CFHashCode: AXUIElement] = [:]
    private var settleTasks: [CFHashCode: Task<Void, Never>] = [:]
    private var trustPoll: Task<Void, Never>?

    /// A zoom animates through several resize notifications; only the final
    /// frame matters.
    private static let settleDelay = Duration.milliseconds(160)

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
            if added != .success {
                let reason = added.rawValue
                Log.workspace.notice(
                    "pid \(pid, privacy: .public) refused \(name, privacy: .public): \(reason, privacy: .public)"
                )
            }
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
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
        settling[key] = element
        settleTasks[key]?.cancel()
        settleTasks[key] = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled, let self else { return }
            settleTasks[key] = nil
            guard let window = settling.removeValue(forKey: key) else { return }
            nudgeIfNeeded(window)
        }
    }

    private func nudgeIfNeeded(_ element: AXUIElement) {
        guard NSEvent.pressedMouseButtons == 0 else {
            Log.workspace.info("Window changed with the mouse down; left alone")
            return
        }
        guard AppWindows.isStandardWindow(element), !AppWindows.isFullScreen(element),
              let reported = AppWindows.frame(of: element) else {
            Log.workspace.info("Window changed but is not a standard, readable window")
            return
        }

        let primaryHeight = displays.primaryHeight
        let frame = Coordinates.appKitRect(fromAccessibility: reported, primaryHeight: primaryHeight)
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
