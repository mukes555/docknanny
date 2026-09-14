import CoreGraphics

/// Which side of a display a dock is anchored to.
///
/// macOS itself supports these three, but every competing multi-display dock
/// assumes `.bottom`. Supporting all three from the start is deliberate.
enum DockEdge: String, Codable, CaseIterable, Sendable {
    case bottom
    case left
    case right

    /// The Dock's own `orientation` preference. Absent means bottom.
    init?(dockOrientation: String?) {
        switch dockOrientation {
        case nil, "bottom": self = .bottom
        case "left": self = .left
        case "right": self = .right
        default: return nil
        }
    }

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
        margin: CGFloat,
        alignment: DockAlignment = .center,
        lengthInset: CGFloat = 0
    ) -> CGRect {
        let clampedLength = min(length, availableLength(againstEdge: edge, of: visibleFrame, margin: margin))
        let size = size(for: edge, thickness: thickness, length: clampedLength)
        let origin = origin(
            for: edge,
            in: visibleFrame,
            size: size,
            along: LengthAlignment(margin: margin, alignment: alignment, inset: lengthInset)
        )
        return CGRect(origin: origin, size: size)
    }

    private static func size(for edge: DockEdge, thickness: CGFloat, length: CGFloat) -> CGSize {
        edge.isVertical
            ? CGSize(width: thickness, height: length)
            : CGSize(width: length, height: thickness)
    }

    /// How a dock is positioned along the edge it is anchored to.
    private struct LengthAlignment {
        let margin: CGFloat
        let alignment: DockAlignment
        /// Transparent padding the panel carries on each side so magnified
        /// tiles are not clipped. Alignment discounts it so the *visible* dock
        /// lands on the margin.
        let inset: CGFloat
    }

    private static func origin(
        for edge: DockEdge,
        in visibleFrame: CGRect,
        size: CGSize,
        along length: LengthAlignment
    ) -> CGPoint {
        switch edge {
        case .bottom:
            let x = alignedOffset(span: visibleFrame.width, length: size.width, along: length)
            return CGPoint(x: visibleFrame.minX + x, y: visibleFrame.minY + length.margin)
        case .left:
            let y = alignedOffset(span: visibleFrame.height, length: size.height, along: length)
            return CGPoint(x: visibleFrame.minX + length.margin, y: visibleFrame.minY + y)
        case .right:
            let y = alignedOffset(span: visibleFrame.height, length: size.height, along: length)
            return CGPoint(x: visibleFrame.maxX - length.margin - size.width, y: visibleFrame.minY + y)
        }
    }

    /// Offset along the anchored edge. `start` means bottom for a vertical dock
    /// and left for a horizontal one, matching AppKit's bottom-left origin.
    private static func alignedOffset(
        span: CGFloat,
        length: CGFloat,
        along placement: LengthAlignment
    ) -> CGFloat {
        let far = span - length
        switch placement.alignment {
        case .start: return max(0, placement.margin - placement.inset)
        case .center: return far / 2
        case .end: return min(far, far - placement.margin + placement.inset)
        }
    }
}
