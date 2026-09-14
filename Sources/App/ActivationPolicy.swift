import AppKit

/// Owns the app's activation policy and, with it, whether the app is active.
///
/// macdock runs as an accessory app, which cannot take keyboard focus, and
/// raises itself to `.regular` only while it has a window worth focusing.
/// Counting open windows in one place is what keeps that correct as windows
/// are added: each controller used to do it for itself, so closing either
/// window dropped the whole app back to `.accessory` while the other was still
/// on screen.
///
/// Activation is deferred one run-loop turn. AppKit refuses an activation
/// requested in the same turn as a policy change, and the window then opens
/// inactive: grey toggles, dim controls, everything faded until the user clicks
/// it. Measured before this change: opening Settings left another app
/// frontmost.
@MainActor
enum ActivationPolicy {
    private static var openWindowCount = 0

    static func windowDidOpen(_ window: NSWindow) {
        openWindowCount += 1
        if openWindowCount == 1 {
            NSApp.setActivationPolicy(.regular)
        }
        activate(bringingFront: window)
    }

    static func windowDidClose() {
        openWindowCount = max(0, openWindowCount - 1)
        guard openWindowCount == 0 else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    /// Activates the app on the next turn and re-asserts the window as key,
    /// because a makeKeyAndOrderFront issued while the app was still inactive
    /// does not survive the activation.
    static func activate(bringingFront window: NSWindow? = nil) {
        DispatchQueue.main.async {
            // Cooperative: macOS grants this only when a user interaction in this
            // app justifies it, which every real path here has. A window opened
            // from a launch argument has none and will open inactive, and the
            // deprecated ignoringOtherApps form no longer changes that.
            NSApp.activate()
            window?.makeKeyAndOrderFront(nil)
        }
    }
}
