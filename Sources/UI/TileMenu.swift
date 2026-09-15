import AppKit

/// The right-click menu for one tile.
///
/// Built by the panel, not by the tile: the panel receives the right-click
/// directly, works out which slot it landed in, and asks for this. That keeps
/// the menu off the view hit-testing path that misrouted left-clicks between
/// overlapping magnified tiles.
///
/// For an app it follows the system Dock's shape: the app's windows first,
/// then what can be done with the app. The one section the Dock has that this
/// cannot is the app's own menu (a browser's profiles, an editor's recent
/// windows): apps hand that to the Dock over a private channel on which the
/// Dock is the server, so no other process can ask for it.
@MainActor
enum TileMenu {
    static func make(for item: DockItem, actions: DockActions, windows: [AppWindow]? = nil) -> NSMenu {
        let menu = NSMenu()
        // With auto-enabling on, an item whose target answers its action is
        // enabled whatever isEnabled says, which made the headers clickable
        // and "Empty Trash..." live with an empty Trash.
        menu.autoenablesItems = false
        switch item.kind {
        case .app:
            addAppItems(to: menu, for: item, actions: actions, windows: windows)
        case .file:
            addHeader(item.name, to: menu)
            menu.addItem(ClosureMenuItem(title: "Open") { actions.activate(item) })
            menu.addItem(ClosureMenuItem(title: "Show in Finder") { actions.reveal(item) })
            menu.addItem(ClosureMenuItem(title: "Remove from Dock") { actions.togglePin(item) })
        case .trash(let isFull):
            addHeader(item.name, to: menu)
            menu.addItem(ClosureMenuItem(title: "Open") { actions.activate(item) })
            let empty = ClosureMenuItem(title: "Empty Trash...") { actions.emptyTrash() }
            empty.isEnabled = isFull
            menu.addItem(empty)
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem(title: "Remove from Dock") { actions.togglePin(item) })
        case .spacer:
            menu.addItem(ClosureMenuItem(title: "Remove Spacer") { actions.togglePin(item) })
        }
        return menu
    }

    private static func addAppItems(to menu: NSMenu, for item: DockItem, actions: DockActions, windows: [AppWindow]?) {
        if item.isRunning {
            addWindowItems(to: menu, for: item, actions: actions, windows: windows)
            menu.addItem(ClosureMenuItem(title: "Show All Windows") { actions.showAllWindows(item) })
        }
        menu.addItem(ClosureMenuItem(title: "Show in Finder") { actions.reveal(item) })
        menu.addItem(ClosureMenuItem(
            title: item.isPinned ? "Remove from Dock" : "Keep in Dock"
        ) { actions.togglePin(item) })

        guard item.isRunning else { return }

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Hide") { actions.hide(item) })
        menu.addItem(ClosureMenuItem(title: "Quit") { actions.quit(item) })
    }

    /// The Dock's window list: a check on the main window, a diamond on a
    /// minimized one. Without Accessibility there is nothing to list, and the
    /// menu says where to grant it rather than silently showing less.
    private static func addWindowItems(
        to menu: NSMenu, for item: DockItem, actions: DockActions, windows: [AppWindow]?
    ) {
        guard let windows else {
            let hint = NSMenuItem(
                title: "Windows are listed here with Accessibility access", action: nil, keyEquivalent: ""
            )
            hint.isEnabled = false
            menu.addItem(hint)
            menu.addItem(ClosureMenuItem(title: "Allow in Setup...") { actions.openSetup() })
            menu.addItem(.separator())
            return
        }
        guard !windows.isEmpty else { return }

        for window in windows {
            let row = ClosureMenuItem(title: window.title) { actions.raiseWindow(item, window) }
            let glyph = window.isMinimized ? "diamond" : "macwindow"
            row.image = NSImage(systemSymbolName: glyph, accessibilityDescription: nil)
            row.state = window.isMain ? .on : .off
            menu.addItem(row)
        }
        menu.addItem(.separator())
    }

    private static func addHeader(_ title: String, to menu: NSMenu) {
        let header = ClosureMenuItem(title: title) {}
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
    }
}

/// An `NSMenuItem` that runs a closure, so menus can be built inline instead of
/// routing every entry through a selector on some controller.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("ClosureMenuItem is built in code, never from a nib")
    }

    @objc
    private func fire() {
        handler()
    }
}
