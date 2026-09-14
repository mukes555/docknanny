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
    private let onOpenSettings: () -> Void
    private let onShowTray: (NSStatusBarButton) -> Void

    var button: NSStatusBarButton? { statusItem.button }

    init(
        onShowTray: @escaping (NSStatusBarButton) -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenSetup: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onShowTray = onShowTray
        self.onOpenSettings = onOpenSettings
        self.onOpenSetup = onOpenSetup
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        configureButton()

        // Left-click drops the tray panel; right-click keeps the classic menu
        // for anyone who wants a menu. The menu is attached only for the
        // duration of the click, or it would swallow left-clicks too.
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        // The brand mark, not a system glyph: this is the most-seen piece of
        // branding the app has. Template rendering is declared in the asset
        // catalogue, which is what lets macOS tint it for light, dark and
        // tinted menu bars.
        button.image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: nil)
        button.image?.isTemplate = true
        button.image?.accessibilityDescription = "macdock"
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let about = NSMenuItem(title: "macdock", action: nil, keyEquivalent: "")
        about.isEnabled = false
        menu.addItem(about)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

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
    private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            statusItem.menu = makeMenu()
            button.performClick(nil)
            statusItem.menu = nil
        } else {
            onShowTray(button)
        }
    }

    @objc
    private func openSettings() {
        onOpenSettings()
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
