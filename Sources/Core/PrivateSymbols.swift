import AppKit

/// Private functions resolved at runtime, each with a stated fallback.
///
/// Nothing here is linked: a symbol Apple removes surfaces as nil, and the
/// caller degrades, rather than dyld aborting the process before any of our
/// code runs. Each one is used for exactly one feature, named beside it.
enum PrivateSymbols {
    private typealias SendNotification = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void

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
