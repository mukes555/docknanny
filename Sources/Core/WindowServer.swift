import AppKit

/// What the window server says about apps' windows.
///
/// Accessibility asks the app, and an app can answer with whatever it likes:
/// iTerm2 reports back the last frame it was asked to take rather than the one
/// it has. The window server draws the windows, so its bounds are the truth,
/// and reading them needs no permission. Only window titles are withheld
/// without Screen Recording, and none are needed here.
enum WindowServer {
    /// On-screen bounds of every app's ordinary windows, by owning process
    /// and window number, in the window server's top-left coordinates. One
    /// copy of the window list serves every app, which is what a sweep over
    /// all of them wants.
    static func windowBoundsByProcess() -> [pid_t: [CGWindowID: CGRect]] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        var bounds: [pid_t: [CGWindowID: CGRect]] = [:]
        for window in windows where window[kCGWindowLayer as String] as? Int == 0 {
            guard let owner = window[kCGWindowOwnerPID as String] as? pid_t,
                  let number = window[kCGWindowNumber as String] as? CGWindowID,
                  let raw = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: raw) else { continue }
            bounds[owner, default: [:]][number] = rect
        }
        return bounds
    }

    /// One app's share of ``windowBoundsByProcess()``.
    static func windowBounds(ofProcess pid: pid_t) -> [CGWindowID: CGRect] {
        windowBoundsByProcess()[pid] ?? [:]
    }
}
