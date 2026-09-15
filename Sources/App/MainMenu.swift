import AppKit

/// The application menu bar.
///
/// An accessory app gets no menu bar for free, and without one the standard key
/// equivalents are inert: with the settings window open, Command-W and
/// Command-Q do nothing at all. The menu is never visible (the app has no Dock
/// tile and does not own the menu bar), but AppKit still routes key equivalents
/// through it.
@MainActor
enum MainMenu {
    static func install() {
        let bar = NSMenu()
        bar.addItem(applicationItem())
        bar.addItem(windowItem())
        NSApp.mainMenu = bar
    }

    private static func applicationItem() -> NSMenuItem {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Settings...",
            action: #selector(AppDelegate.openSettingsFromMenu),
            keyEquivalent: ","
        )
        menu.addItem(.separator())
        // No "Hide DockNanny": hiding an app hides all of its windows, and for
        // this one that means every dock, which nobody asks for by Command-H.
        menu.addItem(
            withTitle: "Quit DockNanny",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let item = NSMenuItem()
        item.submenu = menu
        return item
    }

    private static func windowItem() -> NSMenuItem {
        let menu = NSMenu(title: "Window")
        menu.addItem(
            withTitle: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        menu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )

        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}
