import AppKit
import Testing

@testable import macdock

@Suite("Dragging tiles")
struct DockDragTests {
    private let iconSize: CGFloat = 48
    private let spacing: CGFloat = 6

    private func tile(_ id: String, pinned: Bool, section: DockItem.Section = .apps) -> DockItem {
        DockItem(
            id: id, kind: .app(bundleIdentifier: id), section: section, name: id, icon: nil,
            isRunning: !pinned, isPinned: pinned, isActive: false
        )
    }

    /// Finder and two pins, then two apps that are merely running.
    private var items: [DockItem] {
        [tile("finder", pinned: true), tile("a", pinned: true), tile("b", pinned: true),
         tile("x", pinned: false), tile("y", pinned: false)]
    }

    private func centre(_ index: Int) -> CGFloat {
        DockMetrics.tileCentre(atIndex: index, iconSize: iconSize, spacing: spacing)
    }

    private func landing(_ item: DockItem, over index: Int) -> DockDrag.Landing {
        DockDrag.landing(
            forAxisPosition: centre(index), dragging: item, in: items, iconSize: iconSize, spacing: spacing
        )
    }

    @Test("A pinned tile dragged to the front goes in front of the first tile")
    func pinnedTileToTheFront() {
        let result = landing(items[2], over: 0)
        #expect(result.slot == 0)
        #expect(result.before?.id == "finder")
    }

    @Test("A pinned tile cannot be dropped among the running apps; it stops at the end of the pinned run")
    func pinnedTileStopsAtTheRun() {
        let result = landing(items[2], over: 4)
        #expect(result.slot == 2)
        #expect(result.before == nil)
    }

    @Test("A running tile can land one past the pinned run, which pins it last")
    func runningTileAppendsToTheRun() {
        let result = landing(items[3], over: 4)
        #expect(result.slot == 3)
        #expect(result.before == nil)
    }

    @Test("A running tile dropped among the pins goes in front of the tile it was over")
    func runningTileInsertsAmongPins() {
        let result = landing(items[3], over: 1)
        #expect(result.slot == 1)
        #expect(result.before?.id == "a")
    }

    @Test("Past either end of the slab, the landing clamps to the nearest end of the run")
    func positionsBeyondTheSlabClamp() {
        let early = DockDrag.landing(
            forAxisPosition: -200, dragging: items[2], in: items, iconSize: iconSize, spacing: spacing
        )
        let late = DockDrag.landing(
            forAxisPosition: 9_999, dragging: items[2], in: items, iconSize: iconSize, spacing: spacing
        )
        #expect(early.slot == 0)
        #expect(late.slot == 2)
    }

    @Test("The pinned run stops at the first tile that is not a pinned app")
    func pinnedRunLength() {
        #expect(DockDrag.pinnedRunLength(in: items) == 3)
        #expect(DockDrag.pinnedRunLength(in: []) == 0)
        #expect(DockDrag.pinnedRunLength(in: [tile("x", pinned: false), tile("a", pinned: true)]) == 0)
    }

    @Test("A press becomes a drag only after the pointer has travelled, and only for an app")
    func pressBecomesDragAfterTravel() {
        var press = DockDragSession(item: items[1], index: 1, start: CGPoint(x: 10, y: 10))
        press.update(location: CGPoint(x: 13, y: 10))
        #expect(!press.isDragging)
        #expect(press.isTap(releasedOn: 1))
        press.update(location: CGPoint(x: 30, y: 10))
        #expect(press.isDragging)
        #expect(!press.isTap(releasedOn: 1))

        let trash = DockItem(
            id: "trash", kind: .trash(isFull: false), section: .others, name: "Trash", icon: nil,
            isRunning: false, isPinned: true, isActive: false
        )
        var trashPress = DockDragSession(item: trash, index: 4, start: .zero)
        trashPress.update(location: CGPoint(x: 100, y: 100))
        #expect(!trashPress.isDragging)
    }

    @Test("Releasing on a different tile than the one pressed is not a tap")
    func slidingOffCancelsTheTap() {
        let press = DockDragSession(item: items[1], index: 1, start: .zero)
        #expect(!press.isTap(releasedOn: 2))
        #expect(!press.isTap(releasedOn: nil))
    }
}
