import AppKit

/// Owns the app's activation policy and, with it, whether the app is active.
///
/// macdock runs as an accessory app, which cannot take keyboard focus, and
/// raises itself to `.regular` only while it has a window worth focusing.
/// The open windows are tracked as a set, not a count: showing a window that
/// is already open must not count it twice, or closing it would leave the app
/// in the Dock for good.
///
/// Activation after a policy change is not immediate. AppKit needs the window
/// server to have registered the new policy first; asking one run-loop turn
/// later was sometimes too early, and the Dock tile then appeared with the
/// window still behind everything. So the request waits a little, and is
/// checked and repeated once if it did not take.
@MainActor
enum ActivationPolicy {
    private static var openWindows: Set<ObjectIdentifier> = []

    /// Orders the window front at once, so it is on screen even if activation
    /// is refused, then brings the app forward.
    static func windowDidOpen(_ window: NSWindow) {
        let wasEmpty = openWindows.isEmpty
        openWindows.insert(ObjectIdentifier(window))
        if wasEmpty {
            NSApp.setActivationPolicy(.regular)
        }
        window.makeKeyAndOrderFront(nil)
        activate(bringingFront: window)
    }

    static func windowDidClose(_ window: NSWindow) {
        openWindows.remove(ObjectIdentifier(window))
        guard openWindows.isEmpty else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    /// Activates the app and makes the window key, then checks half a second
    /// later and tries once more if the first attempt did not take.
    ///
    /// Cooperative: macOS grants this only when a user interaction in this app
    /// justifies it, which every real path here has. A window opened from a
    /// launch argument has none and will open inactive.
    static func activate(bringingFront window: NSWindow? = nil, orderingFront: Bool = true) {
        Task { @MainActor in
            for (attempt, delay) in [Duration.milliseconds(100), .milliseconds(500)].enumerated() {
                try? await Task.sleep(for: delay)
                let done = NSApp.isActive && (window == nil || window?.isKeyWindow == true)
                if attempt > 0, done { return }

                NSApp.activate()
                if orderingFront {
                    window?.makeKeyAndOrderFront(nil)
                } else {
                    window?.makeKey()
                }
            }
            if !NSApp.isActive {
                Log.app.notice("Activation was refused; the window is open but not in front")
            }
        }
    }
}
