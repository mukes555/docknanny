import AppKit
import ApplicationServices

/// Private functions resolved at runtime, each with a stated fallback.
///
/// Nothing here is linked: a symbol Apple removes surfaces as nil, and the
/// caller degrades, rather than dyld aborting the process before any of our
/// code runs. Each one is used for exactly one feature, named beside it.
enum PrivateSymbols {
    private typealias SendNotification = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void
    private typealias ElementWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    /// The window number behind an Accessibility window element, which is
    /// what lets the window server's bounds stand in for the app's own
    /// report of its frame. Lives in HIServices, loaded with AppKit. Absent,
    /// the caller falls back to what the app reports.
    private static let elementWindow: ElementWindow? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else {
            Log.privateAPI.notice("_AXUIElementGetWindow is missing; window frames come from the apps themselves")
            return nil
        }
        return unsafeBitCast(symbol, to: ElementWindow.self)
    }()

    static func windowNumber(of element: AXUIElement) -> CGWindowID? {
        guard let elementWindow else { return nil }
        var number: CGWindowID = 0
        guard elementWindow(element, &number) == .success, number != 0 else { return nil }
        return number
    }

    /// "Show All Windows": App Exposé for the front app, the way the Dock's
    /// own menu item does it. Lives in HIServices, already loaded through
    /// AppKit. Returns false when the symbol is gone, so the caller can fall
    /// back to plain activation.
    @MainActor
    static func showAppExpose() -> Bool {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CoreDockSendNotification") else {
            Log.privateAPI.notice("CoreDockSendNotification is missing; Show All Windows only activates the app")
            return false
        }
        let send = unsafeBitCast(symbol, to: SendNotification.self)
        send("com.apple.expose.front.awake" as CFString, nil)
        return true
    }
}
