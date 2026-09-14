import AppKit

/// The right-click menu for one tile.
///
/// Built by the panel, not by the tile: the panel receives the right-click
/// directly, works out which slot it landed in, and asks for this. That keeps
/// the menu off the view hit-testing path that misrouted left-clicks between
/// overlapping magnified tiles.
@MainActor
enum TileMenu {
    static func make(for item: DockItem, actions: DockActions) -> NSMenu {
        let menu = NSMenu()

        let header = ClosureMenuItem(title: item.name) {}
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem(title: "Show in Finder") { actions.reveal(item) })
        menu.addItem(ClosureMenuItem(
            title: item.isPinned ? "Remove from Dock" : "Keep in Dock"
        ) { actions.togglePin(item) })

        guard item.isRunning else { return menu }

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Hide") { actions.hide(item) })
        menu.addItem(ClosureMenuItem(title: "Quit") { actions.quit(item) })
        return menu
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
