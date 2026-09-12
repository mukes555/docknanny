import AppKit

/// Everything a dock tile can do, injected rather than reached for.
///
/// The views need to pin, unpin and quit applications, all of which mutate
/// state they have no business owning. Passing a closure set keeps the view
/// layer free of the settings store while staying far simpler than routing
/// every interaction through a delegate protocol.
@MainActor
struct DockActions {
    var activate: (DockItem) -> Void
    var togglePin: (DockItem) -> Void
    var reveal: (DockItem) -> Void
    var hide: (DockItem) -> Void
    var quit: (DockItem) -> Void
    var pin: (_ bundleIdentifiers: [String]) -> Void

    static let inert = DockActions(
        activate: { _ in },
        togglePin: { _ in },
        reveal: { _ in },
        hide: { _ in },
        quit: { _ in },
        pin: { _ in }
    )
}

/// The side-effecting half of ``DockActions``: everything that talks to
/// NSWorkspace rather than to macdock's own state.
@MainActor
enum DockCommands {
    static func reveal(_ item: DockItem) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.id) else {
            Log.workspace.notice("Cannot reveal an application that is not installed")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func hide(_ item: DockItem) {
        runningApplication(for: item)?.hide()
    }

    /// Asks politely. `terminate()` sends the same request the Dock does, so an
    /// app with unsaved work gets to put up its own sheet instead of losing it.
    static func quit(_ item: DockItem) {
        runningApplication(for: item)?.terminate()
    }

    /// Bundle identifiers for application URLs, used when apps are dropped onto
    /// a dock. Anything that is not a readable bundle is skipped silently: a
    /// stray drag is not worth an alert.
    static func bundleIdentifiers(forDroppedURLs urls: [URL]) -> [String] {
        urls.compactMap { url in
            guard url.pathExtension == "app" else { return nil }
            return Bundle(url: url)?.bundleIdentifier
        }
    }

    private static func runningApplication(for item: DockItem) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == item.id }
    }
}
