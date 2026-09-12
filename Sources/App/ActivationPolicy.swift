import AppKit

/// Owns the app's activation policy.
///
/// macdock runs as an accessory app, which cannot take keyboard focus, and
/// raises itself to `.regular` only while it has a window worth focusing. Each
/// window controller used to do that for itself, so closing either one dropped
/// the whole app back to `.accessory` while the other was still on screen,
/// leaving a visible window that could not be typed into. Counting open windows
/// in one place is the only way that stays correct as windows are added.
@MainActor
enum ActivationPolicy {
    private static var openWindowCount = 0

    static func windowDidOpen() {
        openWindowCount += 1
        guard openWindowCount == 1 else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    static func windowDidClose() {
        openWindowCount = max(0, openWindowCount - 1)
        guard openWindowCount == 0 else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
