import AppKit
import Testing

@testable import DockNanny

@Suite("Tile menus")
@MainActor
struct TileMenuTests {
    private func app(running: Bool, pinned: Bool = true) -> DockItem {
        DockItem(
            id: "com.example.app", kind: .app(bundleIdentifier: "com.example.app"), section: .apps,
            name: "Example", icon: nil, isRunning: running, isPinned: pinned, isActive: false
        )
    }

    private func window(_ title: String, main: Bool = false, minimized: Bool = false) -> AppWindow {
        AppWindow(id: title.hashValue, title: title, isMinimized: minimized, isMain: main,
                  element: AXUIElementCreateApplication(1))
    }

    private func titles(_ menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "-" : $0.title }
    }

    @Test("A running app lists its windows first, main one checked, then the Dock's own items")
    func runningAppWithWindows() {
        let menu = TileMenu.make(
            for: app(running: true), actions: .inert,
            windows: [window("Notes", main: true), window("Drafts", minimized: true)]
        )

        #expect(titles(menu) == [
            "Notes", "Drafts", "-", "Show All Windows", "Show in Finder", "Remove from Dock", "-", "Hide", "Quit"
        ])
        #expect(menu.items[0].state == .on)
        #expect(menu.items[1].state == .off)
    }

    @Test("Without Accessibility the menu says where to grant it instead of quietly listing nothing")
    func runningAppWithoutAccessibility() {
        let menu = TileMenu.make(for: app(running: true), actions: .inert, windows: nil)

        #expect(titles(menu).first == "Windows are listed here with Accessibility access")
        #expect(menu.items[0].isEnabled == false)
        #expect(titles(menu)[1] == "Allow in Setup...")
    }

    @Test("A running app with no windows skips the section entirely")
    func runningAppWithNoWindows() {
        let menu = TileMenu.make(for: app(running: true), actions: .inert, windows: [])
        #expect(titles(menu).first == "Show All Windows")
    }

    @Test("An app that is not running offers only Finder and pinning")
    func notRunning() {
        let menu = TileMenu.make(for: app(running: false, pinned: false), actions: .inert, windows: nil)
        #expect(titles(menu) == ["Show in Finder", "Keep in Dock"])
    }
}
