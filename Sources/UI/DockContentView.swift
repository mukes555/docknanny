import SwiftUI

/// The contents of one dock: a row or column of tiles on a slab.
///
/// The slab is pinned to the anchored edge and the panel is larger than it, so
/// magnified tiles grow into empty space rather than being clipped. All sizing
/// arrives precomputed in ``DockFit``; this view never derives its own, because
/// the window frame is built from the same numbers and the two drifting apart
/// is what put tiles off-screen before.
struct DockContentView: View {
    let items: [DockItem]
    let fit: DockFit
    let configuration: ResolvedDockConfiguration
    var isRevealed: Bool = true
    let actions: DockActions
    var onPointerInside: (Bool) -> Void = { _ in }

    @State private var pointerAxisPosition: CGFloat?
    @State private var isDropTarget = false

    private var visibleItems: [DockItem] {
        Array(items.prefix(fit.visibleItemCount))
    }

    var body: some View {
        Group {
            if isRevealed {
                dock
            } else {
                sliver
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: anchorAlignment)
        .dropDestination(for: URL.self) { urls, _ in
            let identifiers = DockCommands.bundleIdentifiers(forDroppedURLs: urls)
            guard !identifiers.isEmpty else { return false }
            actions.pin(identifiers)
            return true
        } isTargeted: { isDropTarget = $0 }
    }

    /// What auto-hide leaves behind: invisible, but present enough to catch a
    /// pointer pushed against the screen edge.
    private var sliver: some View {
        Color.white.opacity(0.001)
            .contentShape(.rect)
            .onContinuousHover { phase in
                if case .active = phase { onPointerInside(true) }
            }
    }

    private var dock: some View {
        ZStack(alignment: anchorAlignment) {
            DockChrome(
                style: configuration.chromeStyle,
                cornerRadius: DockMetrics.cornerRadius(iconSize: fit.iconSize, configuration: configuration),
                opacity: configuration.chromeOpacity
            )
            .frame(width: fit.slabSize.width, height: fit.slabSize.height)
            .overlay { dropHighlight }
            .overlay { GroupSeparator(fit: fit, configuration: configuration, items: visibleItems) }

            tiles
        }
        .overlay(alignment: anchorAlignment) { hoverLabel }
    }

    /// Dropping an app onto a dock pins it. Without a target highlight the drag
    /// gives no sign it will land.
    @ViewBuilder
    private var dropHighlight: some View {
        if isDropTarget {
            RoundedRectangle(
                cornerRadius: DockMetrics.cornerRadius(iconSize: fit.iconSize, configuration: configuration),
                style: .continuous
            )
            .strokeBorder(.tint, lineWidth: 2)
        }
    }

    /// The slab hugs the screen edge; the headroom sits on the other side.
    private var anchorAlignment: Alignment {
        switch configuration.edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    private var tiles: some View {
        stack
            .frame(width: fit.slabSize.width, height: fit.slabSize.height)
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    pointerAxisPosition = configuration.edge.isVertical ? location.y : location.x
                    onPointerInside(true)
                case .ended:
                    pointerAxisPosition = nil
                    onPointerInside(false)
                }
            }
    }

    @ViewBuilder
    private var stack: some View {
        if configuration.edge.isVertical {
            VStack(spacing: configuration.itemSpacing) { tileViews }
        } else {
            HStack(spacing: configuration.itemSpacing) { tileViews }
        }
    }

    @ViewBuilder
    private var tileViews: some View {
        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
            DockItemView(
                item: item,
                iconSize: fit.iconSize,
                edge: configuration.edge,
                indicatorStyle: configuration.indicatorStyle,
                scale: scale(forTileAt: index),
                actions: actions
            )
        }

        if fit.overflowCount > 0 {
            overflowTile
        }
    }

    /// Shown instead of the last tile when the display is too short to hold
    /// every item, so nothing is dropped without the user being told.
    private var overflowTile: some View {
        RoundedRectangle(cornerRadius: fit.iconSize * 0.22, style: .continuous)
            .fill(.secondary.opacity(0.22))
            .frame(width: fit.iconSize, height: fit.iconSize)
            .overlay {
                Text("+\(fit.overflowCount)")
                    .font(.system(size: fit.iconSize * 0.32, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.5)
            }
            .help("\(fit.overflowCount) more apps do not fit on this display")
            .accessibilityLabel("\(fit.overflowCount) more apps")
    }

    @ViewBuilder
    private var hoverLabel: some View {
        if let index = hoveredIndex, index < visibleItems.count {
            TileLabel(text: visibleItems[index].name)
                .offset(labelOffset(forTileAt: index))
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private var hoveredIndex: Int? {
        guard let pointerAxisPosition else { return nil }
        let reach = (fit.iconSize + configuration.itemSpacing) / 2

        return visibleItems.indices.first { index in
            abs(pointerAxisPosition - centre(ofTileAt: index)) <= reach
        }
    }

    /// Places the label beside the hovered tile, pushed clear of the slab.
    private func labelOffset(forTileAt index: Int) -> CGSize {
        let slabLength = configuration.edge.isVertical ? fit.slabSize.height : fit.slabSize.width
        let alongAxis = centre(ofTileAt: index) - slabLength / 2
        let clearance = DockMetrics.slabThickness(
            iconSize: fit.iconSize,
            spacing: configuration.itemSpacing
        ) + 6

        switch configuration.edge {
        case .bottom: return CGSize(width: alongAxis, height: -clearance)
        case .left: return CGSize(width: clearance, height: alongAxis)
        case .right: return CGSize(width: -clearance, height: alongAxis)
        }
    }

    /// Distance from the slab's leading edge to the centre of tile `index`,
    /// measured along whichever axis the dock runs.
    private func centre(ofTileAt index: Int) -> CGFloat {
        let padding = configuration.itemSpacing
        let stride = fit.iconSize + configuration.itemSpacing
        return padding + fit.iconSize / 2 + CGFloat(index) * stride
    }

    private func scale(forTileAt index: Int) -> CGFloat {
        guard let pointerAxisPosition else { return 1 }
        let distance = abs(pointerAxisPosition - centre(ofTileAt: index))

        guard configuration.isMagnificationEnabled else {
            let isUnderPointer = distance <= fit.iconSize / 2
            return isUnderPointer ? configuration.hoverScale : 1
        }

        return Magnification.scale(
            distance: distance,
            influenceRadius: fit.iconSize * 2.5,
            maximumScale: configuration.magnificationScale
        )
    }
}
