import SwiftUI

/// The application name shown beside a hovered tile.
struct TileLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: .capsule)
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            .fixedSize()
    }
}

/// The hairline between pinned tiles and merely-running ones, matching the
/// system Dock's divider.
///
/// Drawn as an overlay rather than a layout element on purpose: inserting it
/// into the stack would change the slab's length, and ``DockMetrics`` sizes the
/// window from tile counts alone. A divider that silently widened the dock
/// would reintroduce the very mismatch that put tiles off-screen.
struct GroupSeparator: View {
    let fit: DockFit
    let configuration: ResolvedDockConfiguration
    let items: [DockItem]

    private var boundary: Int? {
        guard let first = items.firstIndex(where: { !$0.isPinned }), first > 0 else { return nil }
        return first
    }

    var body: some View {
        if let boundary {
            line
                .offset(offset(at: boundary))
                .allowsHitTesting(false)
        }
    }

    private var line: some View {
        let thickness = fit.iconSize * 0.8
        return Rectangle()
            .fill(.white.opacity(0.18))
            .frame(
                width: configuration.edge.isVertical ? thickness : 1,
                height: configuration.edge.isVertical ? 1 : thickness
            )
    }

    /// Halfway through the gap that already sits between the two tiles.
    private func offset(at boundary: Int) -> CGSize {
        let stride = fit.iconSize + configuration.itemSpacing
        let slabLength = configuration.edge.isVertical ? fit.slabSize.height : fit.slabSize.width
        let position = configuration.itemSpacing + CGFloat(boundary) * stride - configuration.itemSpacing / 2
        let alongAxis = position - slabLength / 2

        return configuration.edge.isVertical
            ? CGSize(width: 0, height: alongAxis)
            : CGSize(width: alongAxis, height: 0)
    }
}
