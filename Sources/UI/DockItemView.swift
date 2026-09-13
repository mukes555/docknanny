import SwiftUI

/// A single application tile.
///
/// Size arrives from the layout rather than being scaled here: a tile drawn
/// at its magnified size occupies exactly the pixels it appears to, which is
/// what lets the surrounding tiles be pushed aside instead of covered.
struct DockItemView: View {
    let item: DockItem
    let size: CGFloat
    let edge: DockEdge
    let indicatorStyle: IndicatorStyle
    /// Clicked to launch and not yet running. Bounces until it is.
    let isLaunching: Bool
    let actions: DockActions

    @State private var bounceOffset: CGFloat = 0
    @State private var isDropTarget = false

    /// A dock is on screen all day. Motion it did not ask for is the thing
    /// people turn this setting on to stop.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        icon
            .frame(width: size, height: size)
            .offset(bounce)
            .overlay(alignment: indicatorAlignment) { indicator }
            .overlay { dropIndicator }
            .contentShape(.rect)
            .draggable(item.id) { dragPreview }
            .dropDestination(for: String.self) { dropped, _ in
                guard let source = dropped.first, source != item.id else { return false }
                actions.move(source, item.id)
                return true
            } isTargeted: { isDropTarget = $0 }
            .onChange(of: isLaunching, initial: true) { _, launching in
                launching ? startBouncing() : settle()
            }
            .help(item.name)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
    }

    /// The system Dock's launch feedback: a repeated hop away from the edge
    /// until the app is up. Stops the moment it is running, or never starts
    /// under Reduce Motion.
    private func startBouncing() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
            bounceOffset = -14
        }
    }

    private func settle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            bounceOffset = 0
        }
    }

    /// Bounces away from whichever edge the dock is anchored to.
    private var bounce: CGSize {
        switch edge {
        case .bottom: CGSize(width: 0, height: bounceOffset)
        case .left: CGSize(width: -bounceOffset, height: 0)
        case .right: CGSize(width: bounceOffset, height: 0)
        }
    }

    private var accessibilityLabel: String {
        guard item.isRunning else { return "\(item.name), not running" }
        return item.isActive ? "\(item.name), active" : "\(item.name), running"
    }

    private var indicatorAlignment: Alignment {
        switch edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let image = item.icon {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(.secondary.opacity(0.25))
                .overlay {
                    Image(systemName: "questionmark")
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var dragPreview: some View {
        Group {
            if let image = item.icon {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 8).fill(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    /// Shows where a dragged tile will land.
    @ViewBuilder
    private var dropIndicator: some View {
        if isDropTarget {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(.tint, lineWidth: 2)
        }
    }

    @ViewBuilder
    private var indicator: some View {
        if item.isRunning, indicatorStyle != .none {
            indicatorShape
                .fill(item.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: indicatorSize.width, height: indicatorSize.height)
                .offset(indicatorOffset)
        }
    }

    private var indicatorShape: AnyShape {
        indicatorStyle == .line ? AnyShape(Capsule()) : AnyShape(Circle())
    }

    private var indicatorSize: CGSize {
        guard indicatorStyle == .line else { return CGSize(width: 5, height: 5) }
        return edge.isVertical
            ? CGSize(width: 3, height: size * 0.4)
            : CGSize(width: size * 0.4, height: 3)
    }

    /// Centred in the slab's padding, as the system Dock's dots are. At the
    /// full padding distance the indicator sat flush with the slab's edge,
    /// which now is also the window's edge.
    private var indicatorOffset: CGSize {
        let distance: CGFloat = 3
        switch edge {
        case .bottom: return CGSize(width: 0, height: distance)
        case .left: return CGSize(width: -distance, height: 0)
        case .right: return CGSize(width: distance, height: 0)
        }
    }
}
