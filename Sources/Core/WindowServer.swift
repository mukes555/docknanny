import AppKit

/// What the window server says about an app's windows.
///
/// Accessibility asks the app, and an app can answer with whatever it likes:
/// iTerm2 reports back the last frame it was asked to take rather than the one
/// it has. The window server draws the windows, so its bounds are the truth,
/// and reading them needs no permission. Only window titles are withheld
/// without Screen Recording, and none are needed here.
enum WindowServer {
    /// On-screen bounds of an app's ordinary windows by window number, in the
    /// window server's top-left coordinates.
    static func windowBounds(ofProcess pid: pid_t) -> [CGWindowID: CGRect] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        var bounds: [CGWindowID: CGRect] = [:]
        for window in windows
        where window[kCGWindowOwnerPID as String] as? pid_t == pid && window[kCGWindowLayer as String] as? Int == 0 {
            guard let number = window[kCGWindowNumber as String] as? CGWindowID,
                  let raw = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: raw) else { continue }
            bounds[number] = rect
        }
        return bounds
    }
}
