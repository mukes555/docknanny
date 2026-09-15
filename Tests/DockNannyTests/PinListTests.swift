import Testing

@testable import DockNanny

@Suite("Pin list edits")
struct PinListTests {
    private let spacer = DockItem.spacerIdentifier

    private func app(_ id: String) -> DockItem {
        DockItem(id: id, kind: .app(bundleIdentifier: id), section: .apps, name: id, icon: nil,
                 isRunning: false, isPinned: true, isActive: false)
    }

    private func spacerTile(_ ordinal: Int) -> DockItem {
        DockItem(id: "spacer:\(ordinal)", kind: .spacer(ordinal: ordinal), section: .apps, name: "", icon: nil,
                 isRunning: false, isPinned: true, isActive: false)
    }

    @Test("Toggling adds an absent app at the end and removes a present one")
    func toggling() {
        #expect(PinList.toggling("c", in: ["a", "b"]) == ["a", "b", "c"])
        #expect(PinList.toggling("a", in: ["a", "b"]) == ["b"])
    }

    @Test("Moving puts an app in front of the target, or at the end for no target")
    func moving() {
        #expect(PinList.moving("c", before: app("a"), in: ["a", "b", "c"]) == ["c", "a", "b"])
        #expect(PinList.moving("a", before: nil, in: ["a", "b", "c"]) == ["b", "c", "a"])
        #expect(PinList.moving("x", before: app("b"), in: ["a", "b"]) == ["a", "x", "b"])
    }

    @Test("A target that is not pinned means the end of the list")
    func movingBeforeAnUnpinnedTarget() {
        #expect(PinList.moving("a", before: app("running"), in: ["a", "b"]) == ["b", "a"])
    }

    @Test("Spacers share one sentinel, so the second spacer is found by counting")
    func spacersAreCounted() {
        let pins = ["a", spacer, "b", spacer, "c"]
        #expect(PinList.moving("c", before: spacerTile(1), in: pins) == ["a", spacer, "b", "c", spacer])
        #expect(PinList.removingSpacer(ordinal: 0, from: pins) == ["a", "b", spacer, "c"])
        #expect(PinList.removingSpacer(ordinal: 5, from: pins) == pins)
    }

    @Test("Adding keeps order and skips what is already there")
    func adding() {
        #expect(PinList.adding(["b", "c", "a"], to: ["a"]) == ["a", "b", "c"])
        #expect(PinList.adding([], to: ["a"]) == ["a"])
    }
}
