import CoreGraphics
import Testing

@testable import DockNanny

/// A generous screen: everything fits at the configured size.
private let roomy: CGFloat = 2000
/// The short axis of a laptop display once margins are taken.
private let cramped: CGFloat = 400

@Suite("Dock fit")
struct DockMetricsTests {
    @Test("When everything fits, nothing is shrunk and nothing overflows")
    func idealCaseIsUntouched() {
        let configuration = TestConfiguration.make(iconSize: 48)
        let fit = DockMetrics.fit(itemCount: 6, configuration: configuration, availableLength: roomy)

        #expect(fit.iconSize == 48)
        #expect(fit.visibleItemCount == 6)
        #expect(fit.overflowCount == 0)
    }

    @Test("A crowded display shrinks tiles before it drops any")
    func shrinkComesBeforeDropping() {
        let configuration = TestConfiguration.make(iconSize: 96)
        let fit = DockMetrics.fit(itemCount: 12, configuration: configuration, availableLength: cramped)

        #expect(fit.iconSize < 96)
        #expect(fit.iconSize >= DockMetrics.minimumIconSize)
        #expect(fit.overflowCount == 0)
        #expect(fit.visibleItemCount == 12)
    }

    @Test("Past the smallest legible tile, items overflow instead of shrinking further")
    func overflowTakesOverAtTheFloor() {
        let configuration = TestConfiguration.make(iconSize: 64)
        let fit = DockMetrics.fit(itemCount: 200, configuration: configuration, availableLength: cramped)

        #expect(fit.iconSize == DockMetrics.minimumIconSize)
        #expect(fit.overflowCount > 0)
        #expect(fit.visibleItemCount + fit.overflowCount == 200)
    }

    @Test("At least one real tile always survives")
    func neverDropsEverything() {
        let configuration = TestConfiguration.make(iconSize: 96)
        let fit = DockMetrics.fit(itemCount: 500, configuration: configuration, availableLength: 40)

        #expect(fit.visibleItemCount >= 1)
    }

    /// The defect this whole type exists to prevent: the window was clamped to
    /// the screen while the content was laid out at full size, so end tiles
    /// rendered outside the panel and could not be clicked.
    @Test("The panel never claims more length than the screen offers")
    func panelAlwaysFitsTheScreen() {
        for count in [0, 1, 3, 9, 27, 81, 200] {
            for iconSize in [24.0, 48.0, 96.0] as [CGFloat] {
                for magnified in [false, true] {
                    for available in [cramped, 900, roomy] as [CGFloat] {
                        let configuration = TestConfiguration.make(
                            iconSize: iconSize,
                            magnified: magnified,
                            magnificationScale: 2.5
                        )
                        let fit = DockMetrics.fit(
                            itemCount: count,
                            configuration: configuration,
                            availableLength: available
                        )
                        let length = configuration.edge.isVertical ? fit.panelSize.height : fit.panelSize.width

                        #expect(
                            length <= available + 0.5,
                            "count \(count) icon \(iconSize) magnified \(magnified): \(length) > \(available)"
                        )
                    }
                }
            }
        }
    }

    @Test("The overflow indicator occupies a real slot")
    func overflowTileIsCountedInLayout() {
        let configuration = TestConfiguration.make(iconSize: 64)
        let crowded = DockMetrics.fit(itemCount: 200, configuration: configuration, availableLength: cramped)
        let roomyFit = DockMetrics.fit(itemCount: 3, configuration: configuration, availableLength: roomy)

        #expect(crowded.drawnTileCount == crowded.visibleItemCount + 1)
        #expect(roomyFit.drawnTileCount == roomyFit.visibleItemCount)
    }

    @Test("The panel is larger than the slab so magnified tiles are not clipped")
    func panelLeavesRoomForGrowth() {
        let configuration = TestConfiguration.make(magnified: true, magnificationScale: 1.6)
        let fit = DockMetrics.fit(itemCount: 4, configuration: configuration, availableLength: roomy)

        #expect(fit.panelSize.width > fit.slabSize.width)
        #expect(fit.panelSize.height > fit.slabSize.height)
    }

    /// One magnitude serves both modes, so the room reserved for growth must
    /// not change when magnification is toggled: only how many tiles reach it
    /// does. A panel that resized on that toggle would jump under the pointer.
    @Test("Headroom is the same whether magnification is on or off")
    func headroomIsModeIndependent() {
        let magnified = TestConfiguration.make(magnified: true, magnificationScale: 2)
        let plain = TestConfiguration.make(magnified: false, magnificationScale: 2)

        #expect(DockMetrics.headroom(iconSize: 48, configuration: magnified) == 48)
        #expect(DockMetrics.headroom(iconSize: 48, configuration: plain) == 48)
    }

    @Test("A dock that never scales needs no headroom")
    func noScalingMeansNoHeadroom() {
        let still = TestConfiguration.make(magnificationScale: 1)
        #expect(DockMetrics.headroom(iconSize: 48, configuration: still) == 0)
    }

    @Test("Tile spacing is counted between tiles, not after the last one")
    func spacingIsCountedBetweenTilesOnly() {
        let length = DockMetrics.slabLength(tileCount: 3, iconSize: 48, spacing: 6)

        let icons: CGFloat = 3 * 48
        let gapsBetween: CGFloat = 2 * 6
        let paddingEachEnd: CGFloat = 2 * 6

        #expect(length == icons + gapsBetween + paddingEachEnd)
    }

    @Test("An empty dock keeps the size of a single tile, so it never collapses")
    func emptyDockKeepsMinimumSize() {
        let empty = DockMetrics.slabLength(tileCount: 0, iconSize: 48, spacing: 6)
        let one = DockMetrics.slabLength(tileCount: 1, iconSize: 48, spacing: 6)

        #expect(empty == one)
    }
}
