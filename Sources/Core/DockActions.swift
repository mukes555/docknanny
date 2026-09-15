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
    /// Files dropped on the dock: apps get pinned, folders and documents join
    /// the section after the apps.
    var drop: (_ urls: [URL]) -> Void
    /// Puts the app in front of the given tile in the pin list, or at the end
    /// of it for nil, pinning it if it was only running.
    var move: (_ identifier: String, _ before: DockItem?) -> Void
    /// Hide every other app, the system Dock's Option-click.
    var hideOthers: (DockItem) -> Void
    var emptyTrash: () -> Void
    /// Files dropped on the Trash tile.
    var trash: (_ urls: [URL]) -> Void
    /// The Dock's "Show All Windows": App Exposé for that app.
    var showAllWindows: (DockItem) -> Void
    var raiseWindow: (DockItem, AppWindow) -> Void
    /// The setup window, where Accessibility can be granted.
    var openSetup: () -> Void

    static let inert = DockActions(
        activate: { _ in },
        togglePin: { _ in },
        reveal: { _ in },
        hide: { _ in },
        quit: { _ in },
        drop: { _ in },
        move: { _, _ in },
        hideOthers: { _ in },
        emptyTrash: {},
        trash: { _ in },
        showAllWindows: { _ in },
        raiseWindow: { _, _ in },
        openSetup: {}
    )
}

/// The side-effecting half of ``DockActions``: everything that talks to
/// NSWorkspace rather than to DockNanny's own state.
@MainActor
enum DockCommands {
    /// What a click means for a tile that is not an app.
    static func open(_ item: DockItem) {
        switch item.kind {
        case .file(let url):
            NSWorkspace.shared.open(url)
        case .trash:
            Trash.open()
        case .app, .spacer:
            return
        }
    }

    static func reveal(_ item: DockItem) {
        switch item.kind {
        case .app(let identifier):
            // The running copy, if there is one: a build under development
            // is not the copy LaunchServices would name as the default.
            let url = runningApplication(for: item)?.bundleURL
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
            guard let url else {
                Log.workspace.notice("Cannot reveal an application that is not installed")
                return
            }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        case .file(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url])
        case .trash:
            Trash.open()
        case .spacer:
            return
        }
    }

    static func hide(_ item: DockItem) {
        runningApplication(for: item)?.hide()
    }

    /// Activates first: App Exposé shows the front app's windows, so the app
    /// has to be in front for the right windows to appear. Without the
    /// private call, activation alone still brings its windows forward.
    static func showAllWindows(_ item: DockItem) {
        guard let application = runningApplication(for: item) else { return }
        if application.isHidden {
            application.unhide()
        }
        application.activate()
        _ = PrivateSymbols.showAppExpose()
    }

    static func raiseWindow(_ item: DockItem, _ window: AppWindow) {
        guard let application = runningApplication(for: item) else { return }
        AppWindows.raise(window, of: application)
    }

    /// The tile menu's window rows. nil means Accessibility is not granted.
    static func windows(of item: DockItem) -> [AppWindow]? {
        guard let application = runningApplication(for: item) else { return nil }
        return AppWindows.list(processIdentifier: application.processIdentifier)
    }

    /// Everything user-facing except the one clicked, and except DockNanny
    /// itself, which has nothing to hide.
    static func hideOthers(_ item: DockItem) {
        let own = Bundle.main.bundleIdentifier
        for application in NSWorkspace.shared.runningApplications
        where application.activationPolicy == .regular
            && application.bundleIdentifier != item.bundleIdentifier
            && application.bundleIdentifier != own {
            application.hide()
        }
    }

    /// Asks politely. `terminate()` sends the same request the Dock does, so an
    /// app with unsaved work gets to put up its own sheet instead of losing it.
    static func quit(_ item: DockItem) {
        runningApplication(for: item)?.terminate()
    }

    /// The process behind a tile, chosen the way the running-apps monitor
    /// chooses what to show: a helper sharing the bundle identifier, or an
    /// instance on its way out, must not be the one hidden, quit or listed.
    private static func runningApplication(for item: DockItem) -> NSRunningApplication? {
        guard let identifier = item.bundleIdentifier else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == identifier && $0.activationPolicy == .regular && !$0.isTerminated
        }
    }
}
