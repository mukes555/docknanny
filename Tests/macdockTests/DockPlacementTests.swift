import CoreGraphics
import Testing

@testable import macdock

/// The geometry of the development machine, captured by the Phase 0 probe.
/// The external display sits at a negative y origin, which is the exact case
/// that breaks placement computed against a shared baseline.
private enum Fixtures {
    static let builtIn = CGRect(x: 0, y: 0, width: 1800, height: 1169)
    static let externalBelowBaseline = CGRect(x: 1800, y: -92, width: 2560, height: 1440)
}

@Suite("Dock placement")
struct DockPlacementTests {
    @Test("A bottom dock sits inside the screen it belongs to")
    func bottomDockStaysOnItsScreen() {
        let frame = DockPlacement.frame(
            againstEdge: .bottom,
            of: Fixtures.builtIn,
            thickness: 60,
            length: 400,
            margin: 8
        )

        #expect(Fixtures.builtIn.contains(frame))
        #expect(frame.minY == Fixtures.builtIn.minY + 8)
    }

    @Test("A dock on a display at negative y stays on that display")
    func negativeOriginDisplayIsHandled() {
        let screen = Fixtures.externalBelowBaseline
        let frame = DockPlacement.frame(
            againstEdge: .bottom,
            of: screen,
            thickness: 60,
            length: 400,
            margin: 8
        )

        #expect(screen.contains(frame))
        #expect(frame.minY == -84)
    }

    @Test("Every edge produces a frame within the screen", arguments: DockEdge.allCases)
    func everyEdgeStaysOnScreen(edge: DockEdge) {
        for screen in [Fixtures.builtIn, Fixtures.externalBelowBaseline] {
            let frame = DockPlacement.frame(
                againstEdge: edge,
                of: screen,
                thickness: 60,
                length: 500,
                margin: 12
            )
            #expect(screen.contains(frame), "\(edge) escaped \(screen)")
        }
    }

    @Test("A dock longer than its screen is clamped rather than overflowing")
    func excessiveLengthIsClamped() {
        let screen = Fixtures.builtIn
        let frame = DockPlacement.frame(
            againstEdge: .bottom,
            of: screen,
            thickness: 60,
            length: 99_999,
            margin: 10
        )

        #expect(screen.contains(frame))
        #expect(frame.width == screen.width - 20)
    }

    @Test("A right-edge dock hugs the right, a left-edge dock hugs the left")
    func verticalEdgesAnchorToTheCorrectSide() {
        let screen = Fixtures.externalBelowBaseline

        let left = DockPlacement.frame(
            againstEdge: .left, of: screen, thickness: 60, length: 400, margin: 8
        )
        let right = DockPlacement.frame(
            againstEdge: .right, of: screen, thickness: 60, length: 400, margin: 8
        )

        #expect(left.minX == screen.minX + 8)
        #expect(right.maxX == screen.maxX - 8)
    }
}
