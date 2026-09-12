import SwiftUI

/// A single application tile.
struct DockItemView: View {
    let item: DockItem
    let iconSize: CGFloat
    let edge: DockEdge
    let onActivate: () -> Void

    @State private var isHovered = false

    private var indicatorAlignment: Alignment {
        switch edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    var body: some View {
        icon
            .frame(width: iconSize, height: iconSize)
            .scaleEffect(isHovered ? 1.12 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isHovered)
            .overlay(alignment: indicatorAlignment) { runningIndicator }
            .contentShape(.rect)
            .onHover { isHovered = $0 }
            .onTapGesture(perform: onActivate)
            .help(item.name)
            .accessibilityLabel(item.name)
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var icon: some View {
        if let image = item.icon {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: iconSize * 0.22)
                .fill(.secondary.opacity(0.25))
                .overlay {
                    Image(systemName: "questionmark")
                        .font(.system(size: iconSize * 0.4, weight: .medium))
                        .foregroundStyle(.secondary)
                }
        }
    }

    @ViewBuilder
    private var runningIndicator: some View {
        if item.isRunning {
            Circle()
                .fill(item.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 5, height: 5)
                .offset(indicatorOffset)
        }
    }

    /// The dot sits just outside the icon, on whichever side faces the screen
    /// edge the dock is anchored to.
    private var indicatorOffset: CGSize {
        let distance: CGFloat = 6
        switch edge {
        case .bottom: return CGSize(width: 0, height: distance)
        case .left: return CGSize(width: -distance, height: 0)
        case .right: return CGSize(width: distance, height: 0)
        }
    }
}
