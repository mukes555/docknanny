import SwiftUI

/// A single application tile.
///
/// Scale is supplied by the parent rather than computed here, because
/// magnification depends on a tile's distance from the pointer and only the
/// container knows where every tile sits.
struct DockItemView: View {
    let item: DockItem
    let iconSize: CGFloat
    let edge: DockEdge
    let indicatorStyle: IndicatorStyle
    let scale: CGFloat
    let actions: DockActions

    var body: some View {
        icon
            .frame(width: iconSize, height: iconSize)
            .scaleEffect(scale, anchor: growthAnchor)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: scale)
            .overlay(alignment: indicatorAlignment) { indicator }
            .contentShape(.rect)
            .onTapGesture { actions.activate(item) }
            .background { TileContextMenu(build: makeMenu) }
            .help(item.name)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        guard item.isRunning else { return "\(item.name), not running" }
        return item.isActive ? "\(item.name), active" : "\(item.name), running"
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(title: item.name) {})
        menu.items.first?.isEnabled = false
        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem(title: "Show in Finder") { actions.reveal(item) })
        menu.addItem(ClosureMenuItem(
            title: item.isPinned ? "Remove from Dock" : "Keep in Dock"
        ) { actions.togglePin(item) })

        guard item.isRunning else { return menu }

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Hide") { actions.hide(item) })
        menu.addItem(ClosureMenuItem(title: "Quit") { actions.quit(item) })
        return menu
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
