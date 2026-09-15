import AppKit
import Testing

@testable import DockNanny

private func runningApp(_ identifier: String, isActive: Bool = false) -> RunningApp {
    RunningApp(
        id: identifier,
        processIdentifier: 1,
        localizedName: identifier,
        icon: nil,
        isActive: isActive
    )
}

private func noIcons(_ kind: DockItem.Kind) -> NSImage? { nil }

@Suite("Dock contents")
struct DockContentsTests {
    @Test("Pinned apps keep their configured order regardless of what is running")
    func pinnedOrderIsStable() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a", "b", "c"], running: [runningApp("c"), runningApp("a")]),
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items.prefix(3).map(\.id) == ["a", "b", "c"])
    }

    @Test("Running apps that are not pinned are appended, never interleaved")
    func unpinnedRunningAppsFollowPinned() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a"], running: [runningApp("z"), runningApp("a")]),
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a", "z"])
        #expect(items[0].isPinned)
        #expect(!items[1].isPinned)
    }

    @Test("A pinned app that is not running still appears, marked as not running")
    func pinnedButNotRunningIsStillShown() {
        let items = DockContents.items(
            source: DockSource(pinned: ["ghost"], running: []),
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items.count == 1)
        #expect(!items[0].isRunning)
    }

    @Test("Turning off running apps leaves only the pinned set")
    func runningAppsCanBeHidden() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a"], running: [runningApp("z")]),
            configuration: TestConfiguration.make(showRunningApps: false),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a"])
    }

    @Test("A per-display allow list filters both pinned and running apps")
    func allowListFiltersEverything() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a", "b"], running: [runningApp("z")]),
            configuration: TestConfiguration.make(allowed: ["a"]),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a"])
    }

    @Test("The active application is marked active")
    func activeApplicationIsFlagged() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a"], running: [runningApp("a", isActive: true)]),
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items[0].isActive)
    }

    @Test("Several processes of one app collapse to a single tile")
    func duplicateRunningAppsCollapse() {
        let items = DockContents.items(
            source: DockSource(pinned: [], running: [runningApp("z"), runningApp("z"), runningApp("z")]),
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["z"])
    }

    @Test("A settings file that repeats a pin still yields unique tile ids")
    func duplicatePinsCollapse() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a", "b", "a"], running: []),
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a", "b"])
    }

    /// Duplicate ids do not merely look wrong: ForEach uses them for identity,
    /// so a collision corrupts SwiftUI's diffing.
    @Test("Tile ids are unique across pinned and running combined")
    func idsAreUniqueOverall() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a", "a"], running: [runningApp("a"), runningApp("b"), runningApp("b")]),
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(Set(items.map(\.id)).count == items.count)
    }

    @Test("Without Recent Applications, running apps share the apps section, as the system Dock's do")
    func runningAppsShareTheAppsSectionByDefault() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a"], running: [runningApp("z")]),
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items.map(\.section) == [.apps, .apps])
    }

    @Test("With Recent Applications on, recents come first in their own section, then other running apps")
    func recentsFormTheirOwnSection() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a"], running: [runningApp("z"), runningApp("a")], recents: ["r", "z"]),
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a", "r", "z"])
        #expect(items.map(\.section) == [.apps, .recents, .recents])
        #expect(!items[1].isRunning)
    }

    @Test("Folders, spacers and the Trash follow the apps in the others section")
    func othersFollowTheApps() {
        let source = DockSource(
            pinned: ["a", DockItem.spacerIdentifier, "b"],
            others: ["file:///Users/nobody/Downloads/", DockItem.spacerIdentifier],
            showsTrash: true,
            isTrashFull: true
        )
        let items = DockContents.items(source: source, configuration: TestConfiguration.make(), iconProvider: noIcons)

        #expect(items.map(\.section) == [.apps, .apps, .apps, .others, .others, .others])
        #expect(items[1].kind == .spacer(ordinal: 0))
        #expect(items[3].fileURL?.path == "/Users/nobody/Downloads")
        #expect(items[4].kind == .spacer(ordinal: 0))
        #expect(items[5].kind == .trash(isFull: true))
        #expect(Set(items.map(\.id)).count == items.count)
    }

    @Test("Something that is not a file URL cannot become a tile")
    func nonFileEntriesAreDropped() {
        let source = DockSource(others: ["https://example.com", "not a url at all"], showsTrash: false)
        let items = DockContents.items(source: source, configuration: TestConfiguration.make(), iconProvider: noIcons)

        #expect(items.isEmpty)
    }

    @Test("Hiding running apps hides the recents too")
    func recentsFollowTheRunningAppsSwitch() {
        let items = DockContents.items(
            source: DockSource(pinned: ["a"], running: [runningApp("z")], recents: ["r"]),
            configuration: TestConfiguration.make(showRunningApps: false),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a"])
    }
}
