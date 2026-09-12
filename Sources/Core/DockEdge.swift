import CoreGraphics

/// Which side of a display a dock is anchored to.
///
/// macOS itself supports these three, but every competing multi-display dock
/// assumes `.bottom`. Supporting all three from the start is deliberate.
enum DockEdge: String, Codable, CaseIterable, Sendable {
    case bottom
    case left
    case right

    var isVertical: Bool {
        self == .left || self == .right
    }

    var localizedName: String {
        switch self {
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        }
    }
}

/// Where a dock panel sits on a display.
///
/// Every measurement is taken from the screen's own `visibleFrame` and never
/// from a shared global origin. Displays routinely sit at negative
/// coordinates: the primary development machine has an external panel at
/// y = -92, and placement computed against a shared baseline puts the dock
/// off-screen there.
enum DockPlacement {
    /// Longest a dock may be before it is clamped to the screen.
    static func availableLength(
        againstEdge edge: DockEdge,
        of visibleFrame: CGRect,
        margin: CGFloat
    ) -> CGFloat {
        let span = edge.isVertical ? visibleFrame.height : visibleFrame.width
        return max(0, span - margin * 2)
    }

    static func frame(
        againstEdge edge: DockEdge,
        of visibleFrame: CGRect,
        thickness: CGFloat,
        length: CGFloat,
        margin: CGFloat
    ) -> CGRect {
        let clampedLength = min(length, availableLength(againstEdge: edge, of: visibleFrame, margin: margin))
        let size = size(for: edge, thickness: thickness, length: clampedLength)
        let origin = origin(for: edge, in: visibleFrame, size: size, margin: margin)
        return CGRect(origin: origin, size: size)
    }

    private static func size(for edge: DockEdge, thickness: CGFloat, length: CGFloat) -> CGSize {
        edge.isVertical
            ? CGSize(width: thickness, height: length)
            : CGSize(width: length, height: thickness)
    }

    private static func origin(
        for edge: DockEdge,
        in visibleFrame: CGRect,
        size: CGSize,
        margin: CGFloat
    ) -> CGPoint {
        let centredHorizontally = visibleFrame.midX - size.width / 2
        let centredVertically = visibleFrame.midY - size.height / 2

        switch edge {
        case .bottom:
            return CGPoint(x: centredHorizontally, y: visibleFrame.minY + margin)
        case .left:
            return CGPoint(x: visibleFrame.minX + margin, y: centredVertically)
        case .right:
            return CGPoint(x: visibleFrame.maxX - margin - size.width, y: centredVertically)
        }
    }
}
