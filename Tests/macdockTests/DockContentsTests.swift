import AppKit
import Testing

@testable import macdock

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
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items.prefix(3).map(\.id) == ["a", "b", "c"])
    }

    @Test("Running apps that are not pinned are appended, never interleaved")
    func unpinnedRunningAppsFollowPinned() {
        let items = DockContents.items(
            pinned: ["a"],
            running: [runningApp("z"), runningApp("a")],
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
            pinned: ["ghost"],
            running: [],
            configuration: TestConfiguration.make(),
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
            configuration: TestConfiguration.make(showRunningApps: false),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a"])
    }

    @Test("A per-display allow list filters both pinned and running apps")
    func allowListFiltersEverything() {
        let items = DockContents.items(
            pinned: ["a", "b"],
            running: [runningApp("z")],
            configuration: TestConfiguration.make(allowed: ["a"]),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["a"])
    }

    @Test("The active application is marked active")
    func activeApplicationIsFlagged() {
        let items = DockContents.items(
            pinned: ["a"],
            running: [runningApp("a", isActive: true)],
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items[0].isActive)
    }

    @Test("Several processes of one app collapse to a single tile")
    func duplicateRunningAppsCollapse() {
        let items = DockContents.items(
            pinned: [],
            running: [runningApp("z"), runningApp("z"), runningApp("z")],
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(items.map(\.id) == ["z"])
    }

    @Test("A settings file that repeats a pin still yields unique tile ids")
    func duplicatePinsCollapse() {
        let items = DockContents.items(
            pinned: ["a", "b", "a"],
            running: [],
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
            pinned: ["a", "a"],
            running: [runningApp("a"), runningApp("b"), runningApp("b")],
            configuration: TestConfiguration.make(),
            iconProvider: noIcons
        )

        #expect(Set(items.map(\.id)).count == items.count)
    }
}
