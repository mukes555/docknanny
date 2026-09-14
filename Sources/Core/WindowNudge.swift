import CoreGraphics

/// The arithmetic of keeping a window clear of a dock, in AppKit coordinates.
///
/// The system Dock gets this from the window server: its strip is left out
/// of every display's visible frame, so a zoomed window stops beside it. The
/// window server keeps exactly one such strip and the Dock rewrites it
/// whenever its contents change, so macdock cannot have one of its own.
/// Instead a window that lands in a dock's strip is moved out of it, and
/// shrunk only when moving is not enough, which is the frame a zoom would
/// have produced had the strip been reserved.
enum WindowNudge {
    /// The band a dock claims along its edge of a display's visible frame.
    static func reservedStrip(edge: DockEdge, thickness: CGFloat, visibleFrame: CGRect) -> CGRect {
        switch edge {
        case .bottom:
            CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width, height: thickness)
        case .left:
            CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: thickness, height: visibleFrame.height)
        case .right:
            CGRect(
                x: visibleFrame.maxX - thickness, y: visibleFrame.minY, width: thickness, height: visibleFrame.height
            )
        }
    }

    /// Where the window should be instead, or nil when it is already clear.
    /// Only the strip's own axis is touched: a window is never moved for a
    /// reason it cannot see.
    static func clearedFrame(window: CGRect, visibleFrame: CGRect, strip: CGRect, edge: DockEdge) -> CGRect? {
        guard window.intersects(strip) else { return nil }

        var cleared = window
        switch edge {
        case .bottom:
            let floor = strip.maxY
            cleared.origin.y = max(window.minY, floor)
            cleared.size.height = min(window.height, visibleFrame.maxY - cleared.minY)
        case .left:
            let wall = strip.maxX
            cleared.origin.x = max(window.minX, wall)
            cleared.size.width = min(window.width, visibleFrame.maxX - cleared.minX)
        case .right:
            let wall = strip.minX
            cleared.origin.x = max(visibleFrame.minX, min(window.minX, wall - window.width))
            cleared.size.width = min(window.width, wall - cleared.minX)
        }

        return cleared == window ? nil : cleared
    }
}
