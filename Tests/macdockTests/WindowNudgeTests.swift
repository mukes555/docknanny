import CoreGraphics
import Testing

@testable import macdock

@Suite("Keeping windows clear of the dock")
struct WindowNudgeTests {
    /// A 1800 by 1169 display with a 39pt menu bar, in AppKit coordinates.
    private let visible = CGRect(x: 0, y: 0, width: 1800, height: 1130)

    private func strip(_ edge: DockEdge, _ thickness: CGFloat = 70) -> CGRect {
        WindowNudge.reservedStrip(edge: edge, thickness: thickness, visibleFrame: visible)
    }

    private func cleared(_ window: CGRect, _ edge: DockEdge) -> CGRect? {
        WindowNudge.clearedFrame(window: window, visibleFrame: visible, strip: strip(edge), edge: edge)
    }

    @Test("The strip hugs the dock's edge for the whole visible frame")
    func stripsHugTheirEdge() {
        #expect(strip(.bottom) == CGRect(x: 0, y: 0, width: 1800, height: 70))
        #expect(strip(.left) == CGRect(x: 0, y: 0, width: 70, height: 1130))
        #expect(strip(.right) == CGRect(x: 1730, y: 0, width: 70, height: 1130))
    }

    @Test("A window already clear of the strip is left alone")
    func clearWindowsAreUntouched() {
        let window = CGRect(x: 100, y: 200, width: 800, height: 600)
        #expect(cleared(window, .bottom) == nil)
        #expect(cleared(window, .left) == nil)
    }

    @Test("A zoomed window is shrunk to the space beside the dock, which is what a reserved strip would have given it")
    func zoomedWindowShrinks() {
        let zoomed = visible
        #expect(cleared(zoomed, .bottom) == CGRect(x: 0, y: 70, width: 1800, height: 1060))
        #expect(cleared(zoomed, .left) == CGRect(x: 70, y: 0, width: 1730, height: 1130))
        #expect(cleared(zoomed, .right) == CGRect(x: 0, y: 0, width: 1730, height: 1130))
    }

    @Test("A window that fits beside the dock is moved, not shrunk")
    func overlappingWindowsMove() {
        let low = CGRect(x: 100, y: 10, width: 800, height: 600)
        #expect(cleared(low, .bottom) == CGRect(x: 100, y: 70, width: 800, height: 600))

        let farRight = CGRect(x: 1200, y: 100, width: 700, height: 600)
        #expect(cleared(farRight, .right) == CGRect(x: 1030, y: 100, width: 700, height: 600))
    }

    @Test("Only the dock's axis changes; a window is never moved for a reason it cannot see")
    func otherAxisIsLeftAlone() {
        let window = CGRect(x: -50, y: 10, width: 800, height: 600)
        let result = cleared(window, .bottom)
        #expect(result?.minX == -50)
        #expect(result?.minY == 70)
    }
}
