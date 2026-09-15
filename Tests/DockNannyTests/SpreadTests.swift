import CoreGraphics
import Testing

@testable import DockNanny

/// The spread layout is what makes magnification behave like the system
/// Dock's, and what guarantees a click can only mean one tile.
@Suite("Spread layout")
struct SpreadTests {
    private let icon: CGFloat = 48
    private let gap: CGFloat = 6
    private let tiles = 8

    private func configuration(magnified: Bool) -> ResolvedDockConfiguration {
        TestConfiguration.make(iconSize: 48, itemSpacing: 6, magnified: magnified, magnificationScale: 1.8)
    }

    private func headroom(_ configuration: ResolvedDockConfiguration) -> CGFloat {
        DockMetrics.lengthHeadroom(iconSize: icon, spacing: gap, configuration: configuration)
    }

    private struct Spread {
        let scales: [CGFloat]
        let centres: [CGFloat]
        let anchor: Int?
    }

    private func layout(pointer: CGFloat?, configuration: ResolvedDockConfiguration) -> Spread {
        let scales = DockMetrics.scales(
            pointerAxisPosition: pointer, tileCount: tiles, iconSize: icon, spacing: gap, configuration: configuration
        )
        let anchor = pointer.flatMap {
            DockMetrics.tileIndex(atAxisPosition: $0, tileCount: tiles, iconSize: icon, spacing: gap)
        }
        let centres = DockMetrics.spreadCentres(
            scales: scales, anchor: anchor, iconSize: icon, spacing: gap, restOrigin: headroom(configuration)
        )
        return Spread(scales: scales, centres: centres, anchor: anchor)
    }

    private var slabLength: CGFloat {
        DockMetrics.slabLength(tileCount: tiles, iconSize: icon, spacing: gap)
    }

    @Test("With no pointer, every tile sits at its resting centre")
    func restIsTheResting() {
        let configuration = configuration(magnified: true)
        let centres = layout(pointer: nil, configuration: configuration).centres

        for index in 0..<tiles {
            let rest = headroom(configuration) + DockMetrics.tileCentre(atIndex: index, iconSize: icon, spacing: gap)
            #expect(abs(centres[index] - rest) < 0.001)
        }
    }

    /// The defect this exists to prevent: magnified tiles covering their
    /// neighbours, so a click on one landed on another.
    @Test("Adjacent tiles are always exactly one gap apart, never overlapping")
    func tilesNeverOverlap() {
        for magnified in [false, true] {
            let configuration = configuration(magnified: magnified)
            for step in stride(from: CGFloat(0), through: slabLength, by: 2.5) {
                let spread = layout(pointer: step, configuration: configuration)
                let (scales, centres) = (spread.scales, spread.centres)
                for index in 1..<tiles {
                    let previousEdge = centres[index - 1] + icon * scales[index - 1] / 2
                    let nextEdge = centres[index] - icon * scales[index] / 2
                    #expect(abs((nextEdge - previousEdge) - gap) < 0.001, "pointer \(step) tile \(index)")
                }
            }
        }
    }

    @Test("The tile under the pointer does not move while it swells")
    func anchoredTileHoldsStill() {
        let configuration = configuration(magnified: true)
        for step in stride(from: CGFloat(0), through: slabLength, by: 3) {
            let spread = layout(pointer: step, configuration: configuration)
            guard let anchor = spread.anchor else { continue }
            let centres = spread.centres
            let rest = headroom(configuration) + DockMetrics.tileCentre(atIndex: anchor, iconSize: icon, spacing: gap)
            #expect(abs(centres[anchor] - rest) < 0.001, "pointer \(step)")
        }
    }

    /// Why slot-based click routing is correct even though tiles move: the
    /// tile visibly under the pointer, when there is one, is always the slot
    /// under the pointer.
    @Test("The slot under the pointer is the tile visibly under it")
    func slotMatchesWhatIsVisible() {
        for magnified in [false, true] {
            let configuration = configuration(magnified: magnified)
            let origin = headroom(configuration)
            for step in stride(from: CGFloat(0), through: slabLength, by: 1.5) {
                let spread = layout(pointer: step, configuration: configuration)
                let visible = (0..<tiles).first { index in
                    abs((step + origin) - spread.centres[index]) <= icon * spread.scales[index] / 2
                }
                if let visible {
                    let slot = String(describing: spread.anchor)
                    #expect(visible == spread.anchor, "pointer \(step): sees \(visible), slot \(slot)")
                }
            }
        }
    }

    @Test("Spreading never pushes a tile past the panel's ends")
    func spreadStaysInsideTheHeadroom() {
        for magnified in [false, true] {
            let configuration = configuration(magnified: magnified)
            let panelLength = slabLength + 2 * headroom(configuration)
            for step in stride(from: CGFloat(0), through: slabLength, by: 2) {
                let spread = layout(pointer: step, configuration: configuration)
                let start = spread.centres[0] - icon * spread.scales[0] / 2 - gap
                let end = spread.centres[tiles - 1] + icon * spread.scales[tiles - 1] / 2 + gap
                #expect(start >= -0.001, "pointer \(step) start \(start)")
                #expect(end <= panelLength + 0.001, "pointer \(step) end \(end) of \(panelLength)")
            }
        }
    }

    @Test("An empty dock spreads to nothing rather than crashing")
    func emptyIsEmpty() {
        let centres = DockMetrics.spreadCentres(scales: [], anchor: 3, iconSize: icon, spacing: gap, restOrigin: 10)
        #expect(centres.isEmpty)
    }
}
