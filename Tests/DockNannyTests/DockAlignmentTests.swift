import CoreGraphics
import Testing

@testable import DockNanny

@Suite("Dock alignment")
struct DockAlignmentTests {
    private let screen = CGRect(x: 1800, y: -92, width: 2560, height: 1440)

    private func frame(_ alignment: DockAlignment, edge: DockEdge = .bottom) -> CGRect {
        DockPlacement.frame(
            againstEdge: edge,
            of: screen,
            thickness: 60,
            length: 400,
            margin: 10,
            alignment: alignment
        )
    }

    @Test("Start, center and end each land somewhere different")
    func alignmentsDiffer() {
        let start = frame(.start).minX
        let centre = frame(.center).minX
        let end = frame(.end).minX

        #expect(start < centre)
        #expect(centre < end)
    }

    @Test("Start hugs the leading edge and end hugs the trailing one")
    func extremesRespectMargin() {
        #expect(frame(.start).minX == screen.minX + 10)
        #expect(frame(.end).maxX == screen.maxX - 10)
    }

    @Test("Every alignment stays on screen, on a display at negative y")
    func allAlignmentsStayOnScreen() {
        for alignment in DockAlignment.allCases {
            for edge in DockEdge.allCases {
                #expect(screen.contains(frame(alignment, edge: edge)), "\(alignment)/\(edge) escaped")
            }
        }
    }

    @Test("A vertical dock aligns along the vertical axis instead")
    func verticalDocksAlignVertically() {
        let start = frame(.start, edge: .left)
        let end = frame(.end, edge: .left)

        #expect(start.minY == screen.minY + 10)
        #expect(end.maxY == screen.maxY - 10)
        #expect(start.minX == end.minX)
    }

    /// The panel carries transparent padding so magnified tiles are not
    /// clipped. Aligning the panel rather than the visible slab left a
    /// start-aligned dock sitting half the headroom short of its own margin.
    @Test("Alignment lines up the visible dock, not its transparent padding")
    func alignmentDiscountsHeadroom() {
        let padded = DockPlacement.frame(
            againstEdge: .bottom, of: screen, thickness: 60, length: 400,
            margin: 40, alignment: .start, lengthInset: 20
        )
        let bare = DockPlacement.frame(
            againstEdge: .bottom, of: screen, thickness: 60, length: 400,
            margin: 40, alignment: .start, lengthInset: 0
        )

        #expect(padded.minX == bare.minX - 20)
        #expect(padded.minX >= screen.minX)
    }

    @Test("A headroom larger than the margin does not push the dock off screen")
    func insetCannotEscapeTheScreen() {
        for alignment in [DockAlignment.start, .end] {
            let frame = DockPlacement.frame(
                againstEdge: .bottom, of: screen, thickness: 60, length: 400,
                margin: 4, alignment: alignment, lengthInset: 200
            )
            #expect(screen.contains(frame), "\(alignment) escaped with an oversized inset")
        }
    }

    @Test("Center alignment ignores the inset, because padding is symmetric there")
    func centreIsUnaffected() {
        let padded = DockPlacement.frame(
            againstEdge: .bottom, of: screen, thickness: 60, length: 400,
            margin: 10, alignment: .center, lengthInset: 50
        )
        let bare = DockPlacement.frame(
            againstEdge: .bottom, of: screen, thickness: 60, length: 400,
            margin: 10, alignment: .center, lengthInset: 0
        )

        #expect(padded == bare)
    }
}
