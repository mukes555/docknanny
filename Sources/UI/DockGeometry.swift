import CoreGraphics

/// The content view's coordinate system, in one place.
///
/// Positions in a dock are given along its axis (the screen edge it hugs)
/// and by depth (distance in from that edge). Everything the view draws is
/// placed with this, so the chrome, the tiles, the separators, the label and
/// the click routing cannot disagree about where a slot is.
struct DockGeometry {
    let fit: DockFit
    let edge: DockEdge
    let spacing: CGFloat

    var iconSize: CGFloat { fit.iconSize }
    var isVertical: Bool { edge.isVertical }
    var slabThickness: CGFloat { DockMetrics.slabThickness(iconSize: iconSize, spacing: spacing) }
    var panelThickness: CGFloat { isVertical ? fit.panelSize.width : fit.panelSize.height }

    func axis(of point: CGPoint) -> CGFloat {
        isVertical ? point.y : point.x
    }

    /// Panel coordinates for a point given along the axis and by depth.
    func point(axis: CGFloat, depth: CGFloat) -> CGPoint {
        switch edge {
        case .bottom: CGPoint(x: axis, y: panelThickness - depth)
        case .left: CGPoint(x: depth, y: axis)
        case .right: CGPoint(x: panelThickness - depth, y: axis)
        }
    }

    /// Slot space is the resting slab's own axis, starting at the headroom.
    func slotPosition(of point: CGPoint) -> CGFloat {
        axis(of: point) - fit.lengthHeadroom
    }

    func tileIndex(at point: CGPoint, tileCount: Int) -> Int? {
        guard let index = DockMetrics.tileIndex(
            atAxisPosition: slotPosition(of: point), tileCount: fit.drawnTileCount, iconSize: iconSize, spacing: spacing
        ), index < tileCount else { return nil }
        return index
    }

    /// Just past the slab's outer edge, over a tile's resting centre.
    func menuAnchor(forTile index: Int) -> CGPoint {
        let centre = DockMetrics.tileCentre(atIndex: index, iconSize: iconSize, spacing: spacing)
        return point(axis: fit.lengthHeadroom + centre, depth: slabThickness)
    }

    /// Where the glass currently starts and ends along the axis, following
    /// the tiles as they spread.
    func liveSlab(centres: [CGFloat], scales: [CGFloat]) -> ClosedRange<CGFloat> {
        guard let first = centres.first, let last = centres.last,
              let firstScale = scales.first, let lastScale = scales.last else {
            let restLength = isVertical ? fit.slabSize.height : fit.slabSize.width
            return fit.lengthHeadroom...(fit.lengthHeadroom + restLength)
        }
        let start = first - iconSize * firstScale / 2 - spacing
        let end = last + iconSize * lastScale / 2 + spacing
        return min(start, end)...max(start, end)
    }
}
