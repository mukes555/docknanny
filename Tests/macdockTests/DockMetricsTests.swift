import CoreGraphics
import Testing

@testable import macdock

private func configuration(edge: DockEdge) -> ResolvedDockConfiguration {
    ResolvedDockConfiguration(
        isEnabled: true,
        edge: edge,
        iconSize: 48,
        margin: 8,
        itemSpacing: 6,
        showRunningApps: true,
        allowedBundleIdentifiers: nil
    )
}

@Suite("Dock metrics")
struct DockMetricsTests {
    @Test("A horizontal dock grows along its width and keeps a fixed thickness")
    func horizontalDockGrowsInWidth() {
        let one = DockMetrics.panelSize(itemCount: 1, configuration: configuration(edge: .bottom))
        let five = DockMetrics.panelSize(itemCount: 5, configuration: configuration(edge: .bottom))

        let expectedThickness: CGFloat = 48 + 12

        #expect(five.width > one.width)
        #expect(five.height == one.height)
        #expect(one.height == expectedThickness)
    }

    @Test("A vertical dock grows along its height instead")
    func verticalDockGrowsInHeight() {
        let one = DockMetrics.panelSize(itemCount: 1, configuration: configuration(edge: .left))
        let five = DockMetrics.panelSize(itemCount: 5, configuration: configuration(edge: .left))

        #expect(five.height > one.height)
        #expect(five.width == one.width)
    }

    @Test("An empty dock still has the size of a single tile, so it never collapses")
    func emptyDockKeepsMinimumSize() {
        let empty = DockMetrics.panelSize(itemCount: 0, configuration: configuration(edge: .bottom))
        let one = DockMetrics.panelSize(itemCount: 1, configuration: configuration(edge: .bottom))

        #expect(empty == one)
    }

    @Test("Tile spacing is counted between tiles, not after the last one")
    func spacingIsCountedBetweenTilesOnly() {
        let three = DockMetrics.panelSize(itemCount: 3, configuration: configuration(edge: .bottom))

        let icons: CGFloat = 3 * 48
        let gapsBetween: CGFloat = 2 * 6
        let paddingEachEnd: CGFloat = 2 * 6

        #expect(three.width == icons + gapsBetween + paddingEachEnd)
    }
}
