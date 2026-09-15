import AppKit

/// The app's own icon, read from its asset catalogue.
///
/// `NSApp.applicationIconImage` comes from Icon Services, which caches by
/// bundle path: after the icon changes, a rebuilt app at the same path keeps
/// showing the old one in its own windows and on its Dock tile until the
/// cache notices. The catalogue is what was actually built, so the app reads
/// it directly and tells AppKit to use it too.
@MainActor
enum Brand {
    static let appIcon: NSImage = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage

    /// Called once at launch: the Dock tile, the About panel and the app
    /// switcher then show the built icon rather than a cached one.
    static func installAppIcon() {
        NSApp.applicationIconImage = appIcon
    }
}
