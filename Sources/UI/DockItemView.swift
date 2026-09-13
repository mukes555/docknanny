import SwiftUI

/// A single application tile.
///
/// Purely visual plus drag: it has no tap gesture and no menu of its own. Both
/// are resolved by the container from the pointer's position along the dock,
/// because a tile magnified in place overlaps its neighbours and per-tile hit
/// testing then opened the wrong app.
struct DockItemView: View {
    let item: DockItem
    let iconSize: CGFloat
    let edge: DockEdge
    let indicatorStyle: IndicatorStyle
    let scale: CGFloat
    let actions: DockActions

    @State private var bounceOffset: CGFloat = 0
    @State private var isDropTarget = false

    /// A dock is on screen all day. Motion it did not ask for is the thing
    /// people turn this setting on to stop.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        icon
            .frame(width: iconSize, height: iconSize)
            .scaleEffect(scale, anchor: growthAnchor)
            .offset(bounce)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: scale)
            .overlay(alignment: indicatorAlignment) { indicator }
            .overlay { dropIndicator }
            .contentShape(.rect)
            .draggable(item.id) { dragPreview }
            .dropDestination(for: String.self) { dropped, _ in
                guard let source = dropped.first, source != item.id else { return false }
                actions.move(source, item.id)
                return true
            } isTargeted: { isDropTarget = $0 }
            .onChange(of: item.isRunning) { wasRunning, isRunning in
                guard !wasRunning, isRunning else { return }
                playLaunchBounce()
            }
            .help(item.name)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
    }

    /// A hop away from the screen edge when an app finishes launching, the
    /// same confirmation the system Dock gives. Deliberately one hop: the
    /// system's repeat-until-ready bounce is the most complained-about
    /// animation macOS has.
    private func playLaunchBounce() {
        // The tile still ends up where it belongs; it simply does not hop to
        // get there. Suppressed entirely rather than shortened, because a
        // shorter hop is still a hop.
        guard !reduceMotion else { return }

        withAnimation(.interpolatingSpring(stiffness: 340, damping: 12)) {
            bounceOffset = -14
        }
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 14).delay(0.14)) {
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

    private var dragPreview: some View {
        Group {
            if let image = item.icon {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 8).fill(.secondary)
            }
        }
        .frame(width: iconSize, height: iconSize)
    }

    /// Shows where a dragged tile will land.
    @ViewBuilder
    private var dropIndicator: some View {
        if isDropTarget {
            RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
                .strokeBorder(.tint, lineWidth: 2)
        }
    }

    private var accessibilityLabel: String {
        guard item.isRunning else { return "\(item.name), not running" }
        return item.isActive ? "\(item.name), active" : "\(item.name), running"
    }

    /// Tiles grow away from the screen edge, never through it.
    private var growthAnchor: UnitPoint {
        switch edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
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
            RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
                .fill(.secondary.opacity(0.25))
                .overlay {
                    Image(systemName: "questionmark")
                        .font(.system(size: iconSize * 0.4, weight: .medium))
                        .foregroundStyle(.secondary)
                }
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
            ? CGSize(width: 3, height: iconSize * 0.4)
            : CGSize(width: iconSize * 0.4, height: 3)
    }

    private var indicatorOffset: CGSize {
        let distance: CGFloat = 6
        switch edge {
        case .bottom: return CGSize(width: 0, height: distance)
        case .left: return CGSize(width: -distance, height: 0)
        case .right: return CGSize(width: distance, height: 0)
        }
    }
}
