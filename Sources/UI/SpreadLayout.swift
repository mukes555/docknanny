import SwiftUI

/// Places dock tiles at precomputed centres along the dock's axis, sized by
/// their magnification, and anchored to the screen edge on the other axis.
///
/// The centres come from ``DockMetrics/spreadCentres`` so the layout, the
/// chrome, the separator, the label and the click routing all read from the
/// same numbers. The layout itself holds no opinion about where anything goes.
struct SpreadLayout: Layout {
    let edge: DockEdge
    let iconSize: CGFloat
    let spacing: CGFloat
    let centres: [CGFloat]
    let scales: [CGFloat]
    /// A slot to leave empty, mid-drag: the subviews after it shift along one.
    var skippedSlot: Int?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (position, subview) in subviews.enumerated() {
            let index = slot(forSubview: position)
            guard index < centres.count else { continue }
            let scale = index < scales.count ? scales[index] : 1
            let side = iconSize * scale
            let size = ProposedViewSize(width: side, height: side)
            let centre = centres[index]

            switch edge {
            case .bottom:
                subview.place(
                    at: CGPoint(x: bounds.minX + centre, y: bounds.maxY - spacing),
                    anchor: .bottom,
                    proposal: size
                )
            case .left:
                subview.place(
                    at: CGPoint(x: bounds.minX + spacing, y: bounds.minY + centre),
                    anchor: .leading,
                    proposal: size
                )
            case .right:
                subview.place(
                    at: CGPoint(x: bounds.maxX - spacing, y: bounds.minY + centre),
                    anchor: .trailing,
                    proposal: size
                )
            }
        }
    }

    private func slot(forSubview position: Int) -> Int {
        guard let skippedSlot, position >= skippedSlot else { return position }
        return position + 1
    }
}
