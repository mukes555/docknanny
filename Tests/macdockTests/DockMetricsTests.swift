import CoreGraphics
import Testing

@testable import macdock

@Suite("Dock metrics")
struct DockMetricsTests {
    // MARK: Slab, the visible bar behind the tiles

    @Test("A horizontal slab grows along its width and keeps a fixed thickness")
    func horizontalSlabGrowsInWidth() {
        let configuration = TestConfiguration.make(edge: .bottom)
        let one = DockMetrics.slabSize(itemCount: 1, configuration: configuration)
        let five = DockMetrics.slabSize(itemCount: 5, configuration: configuration)
        let expectedThickness: CGFloat = 48 + 12

        #expect(five.width > one.width)
        #expect(five.height == one.height)
        #expect(one.height == expectedThickness)
    }

    @Test("A vertical slab grows along its height instead")
    func verticalSlabGrowsInHeight() {
        let configuration = TestConfiguration.make(edge: .left)
        let one = DockMetrics.slabSize(itemCount: 1, configuration: configuration)
        let five = DockMetrics.slabSize(itemCount: 5, configuration: configuration)

        #expect(five.height > one.height)
        #expect(five.width == one.width)
    }

    @Test("An empty dock keeps the size of a single tile, so it never collapses")
    func emptyDockKeepsMinimumSize() {
        let configuration = TestConfiguration.make()
        let empty = DockMetrics.slabSize(itemCount: 0, configuration: configuration)
        let one = DockMetrics.slabSize(itemCount: 1, configuration: configuration)

        #expect(empty == one)
    }

    @Test("Tile spacing is counted between tiles, not after the last one")
    func spacingIsCountedBetweenTilesOnly() {
        let three = DockMetrics.slabSize(itemCount: 3, configuration: TestConfiguration.make())

        let icons: CGFloat = 3 * 48
        let gapsBetween: CGFloat = 2 * 6
        let paddingEachEnd: CGFloat = 2 * 6

        #expect(three.width == icons + gapsBetween + paddingEachEnd)
    }

    // MARK: Panel, the window, which must leave room for tiles to swell

    @Test("The panel is larger than the slab, so magnified tiles are not clipped")
    func panelLeavesRoomForGrowth() {
        let configuration = TestConfiguration.make(magnified: true, magnificationScale: 1.6)
        let slab = DockMetrics.slabSize(itemCount: 4, configuration: configuration)
        let panel = DockMetrics.panelSize(itemCount: 4, configuration: configuration)

        #expect(panel.height > slab.height)
        #expect(panel.width > slab.width)
    }

    @Test("Headroom follows whichever scale is actually in play")
    func headroomTracksTheActiveScale() {
        let magnified = TestConfiguration.make(magnified: true, magnificationScale: 2, hoverScale: 1.1)
        let plain = TestConfiguration.make(magnified: false, magnificationScale: 2, hoverScale: 1.1)

        #expect(DockMetrics.headroom(for: magnified) == 48)
        #expect(DockMetrics.headroom(for: plain) > 0)
        #expect(DockMetrics.headroom(for: plain) < DockMetrics.headroom(for: magnified))
    }

    @Test("A dock that never scales needs no headroom")
    func noScalingMeansNoHeadroom() {
        let still = TestConfiguration.make(magnified: false, hoverScale: 1)
        #expect(DockMetrics.headroom(for: still) == 0)
    }
}
