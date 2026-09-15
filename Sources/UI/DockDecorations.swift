import SwiftUI

/// Hairlines in the gaps where one section ends and the next begins,
/// wherever those gaps currently are.
struct SectionSeparators: View {
    let items: [DockItem]
    let centres: [CGFloat]
    let scales: [CGFloat]
    let geometry: DockGeometry

    private var boundaries: [Int] {
        items.indices.dropFirst().filter { items[$0].section != items[$0 - 1].section }
    }

    var body: some View {
        ForEach(boundaries, id: \.self) { boundary in
            if boundary < centres.count, boundary < scales.count {
                let iconSize = geometry.iconSize
                let before = centres[boundary - 1] + iconSize * scales[boundary - 1] / 2
                let after = centres[boundary] - iconSize * scales[boundary] / 2
                let length = iconSize * 0.8

                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: geometry.isVertical ? length : 1, height: geometry.isVertical ? 1 : length)
                    .position(geometry.point(axis: (before + after) / 2, depth: geometry.slabThickness / 2))
                    .allowsHitTesting(false)
            }
        }
    }
}

/// The hovered tile's name, riding clear of the icon at whatever size the
/// icon currently is, the way the system Dock's does.
struct HoverLabel: View {
    let text: String
    let centre: CGFloat
    let scale: CGFloat
    let geometry: DockGeometry

    var body: some View {
        // The tile's far edge as the layout places it: one spacing in from
        // the screen edge, then the icon at its current size.
        let iconReach = geometry.spacing + geometry.iconSize * scale
        let depth = iconReach + (geometry.isVertical ? 8 + DockMetrics.labelMaximumWidth / 2 : 14)

        TileLabel(text: text)
            .frame(width: geometry.isVertical ? DockMetrics.labelMaximumWidth : nil, alignment: alignment)
            .position(geometry.point(axis: centre, depth: depth))
            .allowsHitTesting(false)
            .transition(.opacity)
    }

    private var alignment: Alignment {
        switch geometry.edge {
        case .bottom: .center
        case .left: .leading
        case .right: .trailing
        }
    }
}

/// Shown instead of the last tile when the display is too short to hold
/// every item, so nothing is dropped without the user being told.
struct OverflowTile: View {
    let count: Int
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(.secondary.opacity(0.22))
            .frame(width: size, height: size)
            .overlay {
                Text("+\(count)")
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.5)
            }
            .help("\(count) more apps do not fit on this display")
            .accessibilityLabel("\(count) more apps")
    }
}
