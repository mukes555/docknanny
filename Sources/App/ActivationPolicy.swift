import AppKit

/// Owns the app's activation policy and, with it, whether the app is active.
///
/// DockNanny runs as an accessory app, which cannot take keyboard focus, and
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
    static func activate(bringingFront window: NSWindow? = nil, orderingFront: Bool = true) {
        Task { @MainActor in
            for (attempt, delay) in [Duration.milliseconds(100), .milliseconds(500)].enumerated() {
                try? await Task.sleep(for: delay)
                let done = NSApp.isActive && (window == nil || window?.isKeyWindow == true)
                if attempt > 0, done { return }

                activateNow()
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

    /// The plain `activate()` is cooperative: macOS grants it only after a
    /// user interaction it recognises, and a click on a status item is not
    /// one, so the tray opened faded and Set Up opened behind everything.
    /// Naming the app in front as the one yielding is the macOS 14 form of
    /// the same request and is honoured, measured on macOS 26, even for a
    /// background app with no interaction at all. Every activation in the
    /// app goes through here so the day it stops working there is one place
    /// to change.
    static func activateNow() {
        guard let front = NSWorkspace.shared.frontmostApplication, !front.isEqual(NSRunningApplication.current) else {
            NSApp.activate()
            return
        }
        NSRunningApplication.current.activate(from: front, options: [])
    }
}
