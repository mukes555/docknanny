import AppKit
import Testing

@testable import macdock

private extension ResolvedDockConfiguration {
    static func make(
        showRunningApps: Bool = true,
        allowed: [String]? = nil
    ) -> ResolvedDockConfiguration {
        ResolvedDockConfiguration(
            isEnabled: true,
            edge: .bottom,
            iconSize: 48,
            margin: 8,
            itemSpacing: 6,
            showRunningApps: showRunningApps,
            allowedBundleIdentifiers: allowed
        )
    }
}

private func runningApp(_ identifier: String, isActive: Bool = false) -> RunningApp {
    RunningApp(
        id: identifier,
        processIdentifier: 1,
        localizedName: identifier,
        icon: nil,
        isActive: isActive
    )
}

private func noIcons(_ bundleIdentifier: String) -> NSImage? { nil }

@Suite("Dock contents")
struct DockContentsTests {
    @Test("Pinned apps keep their configured order regardless of what is running")
    func pinnedOrderIsStable() {
        let items = DockContents.items(
            pinned: ["a", "b", "c"],
            running: [runningApp("c"), runningApp("a")],
            configuration: .make(),
            iconProvider: noIcons
        )

        #expect(items.prefix(3).map(\.id) == ["a", "b", "c"])
    }

    @Test("Running apps that are not pinned are appended, never interleaved")
    func unpinnedRunningAppsFollowPinned() {
        let items = DockContents.items(
            pinned: ["a"],
            running: [runningApp("z"), runningApp("a")],
            configuration: .make(),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a", "z"])
        #expect(items[0].isPinned)
        #expect(!items[1].isPinned)
    }

    @Test("A pinned app that is not running still appears, marked as not running")
    func pinnedButNotRunningIsStillShown() {
        let items = DockContents.items(
            pinned: ["ghost"],
            running: [],
            configuration: .make(),
            iconProvider: noIcons
        )

        #expect(items.count == 1)
        #expect(!items[0].isRunning)
    }

    @Test("Turning off running apps leaves only the pinned set")
    func runningAppsCanBeHidden() {
        let items = DockContents.items(
            pinned: ["a"],
            running: [runningApp("z")],
            configuration: .make(showRunningApps: false),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a"])
    }

    @Test("A per-display allow list filters both pinned and running apps")
    func allowListFiltersEverything() {
        let items = DockContents.items(
            pinned: ["a", "b"],
            running: [runningApp("z")],
            configuration: .make(allowed: ["a"]),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a"])
    }

    @Test("The active application is marked active")
    func activeApplicationIsFlagged() {
        let items = DockContents.items(
            pinned: ["a"],
            running: [runningApp("a", isActive: true)],
            configuration: .make(),
            iconProvider: noIcons
        )

        #expect(items[0].isActive)
    }
}
