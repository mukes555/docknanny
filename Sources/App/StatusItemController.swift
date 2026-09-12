import AppKit

/// The menu bar presence.
///
/// macdock runs as an accessory app with no tile in the system Dock, so this
/// is the only way to reach it. The icon is a template image, which is what
/// lets macOS tint it correctly in light, dark and tinted menu bars.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let onQuit: () -> Void
    private let onOpenSetup: () -> Void

    init(onOpenSetup: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenSetup = onOpenSetup
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        configureButton()
        statusItem.menu = makeMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "menubar.dock.rectangle",
            accessibilityDescription: "macdock"
        )
        button.image?.isTemplate = true
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let about = NSMenuItem(title: "macdock", action: nil, keyEquivalent: "")
        about.isEnabled = false
        menu.addItem(about)
        menu.addItem(.separator())

        let setup = NSMenuItem(title: "Set Up macdock...", action: #selector(openSetup), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit macdock",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc
    private func openSetup() {
        onOpenSetup()
    }

    @objc
    private func quit() {
        onQuit()
    }
}
