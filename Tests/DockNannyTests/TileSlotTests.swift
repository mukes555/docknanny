import CoreGraphics
import Testing

@testable import DockNanny

/// The routing bug: a magnified tile swelled over its neighbours, and view
/// hit-testing sent the click to whichever sibling was drawn last. Clicks now
/// resolve by slot, so these pin the slot maths.
@Suite("Tile slots")
struct TileSlotTests {
    private let icon: CGFloat = 52
    private let gap: CGFloat = 6

    private func index(_ position: CGFloat, count: Int = 10) -> Int? {
        DockMetrics.tileIndex(atAxisPosition: position, tileCount: count, iconSize: icon, spacing: gap)
    }

    @Test("The centre of every tile resolves to that tile")
    func centresResolveToThemselves() {
        for tile in 0..<10 {
            let centre = DockMetrics.tileCentre(atIndex: tile, iconSize: icon, spacing: gap)
            #expect(index(centre) == tile, "tile \(tile)")
        }
    }

    @Test("A point in the gap resolves to the nearer tile, never to nothing")
    func gapsBelongToTheNearerTile() {
        let first = DockMetrics.tileCentre(atIndex: 0, iconSize: icon, spacing: gap)
        let second = DockMetrics.tileCentre(atIndex: 1, iconSize: icon, spacing: gap)
        let midpoint = (first + second) / 2

        #expect(index(midpoint - 1) == 0)
        #expect(index(midpoint + 1) == 1)
    }

    /// The exact failure: 52pt tiles, 1.8x hover, a click 15pt past a tile's
    /// own edge is visually on the swollen tile and must open that tile, not
    /// the neighbour whose unscaled frame the point happens to fall in.
    @Test("A click on a swollen tile's overhang still maps by slot, deterministically")
    func swollenOverhangIsDeterministic() {
        let first = DockMetrics.tileCentre(atIndex: 0, iconSize: icon, spacing: gap)
        let stride = icon + gap

        // Anywhere within half a stride of a centre is that tile's slot, full stop.
        #expect(index(first + stride / 2 - 0.01) == 0)
        #expect(index(first + stride / 2 + 0.01) == 1)
    }

    @Test("Before the first slot and after the last resolve to nothing")
    func outsideIsNil() {
        #expect(index(-5) == nil)
        // The slab's own end padding is claimed by the end tiles: a magnified
        // first tile visibly extends into it, and a click there means that tile.
        #expect(index(0) == 0)
        let last = DockMetrics.tileCentre(atIndex: 9, iconSize: icon, spacing: gap)
        #expect(index(last + (icon + gap)) == nil)
        #expect(index(100, count: 0) == nil)
    }

    @Test("The slab hugs its anchored edge inside the panel", arguments: DockEdge.allCases)
    func slabHugsItsEdge(edge: DockEdge) {
        let configuration = TestConfiguration.make(edge: edge, iconSize: 52, magnificationScale: 1.8)
        let fit = DockMetrics.fit(itemCount: 8, configuration: configuration, availableLength: 1200)
        let slab = DockMetrics.slabFrame(fit: fit, edge: edge)

        switch edge {
        case .bottom: #expect(slab.maxY == fit.panelSize.height)
        case .left: #expect(slab.minX == 0)
        case .right: #expect(slab.maxX == fit.panelSize.width)
        }
        #expect(slab.size == fit.slabSize)
    }
}
