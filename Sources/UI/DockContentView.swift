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
                tint: configuration.tint
            )
            .frame(width: fit.slabSize.width, height: fit.slabSize.height)
            .overlay { dropHighlight }
            .overlay { GroupSeparator(fit: fit, configuration: configuration, items: visibleItems) }

            tiles
        }
        // Sized and anchored explicitly, so the slab lands where
        // DockMetrics.slabFrame says it does regardless of what the hosting
        // view proposes. Left as maxWidth: .infinity, a left-edge dock rendered
        // with its slab flush right, 68pt off the screen edge.
        .frame(width: fit.panelSize.width, height: fit.panelSize.height, alignment: anchorAlignment)
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
            .contentShape(.rect)
            // One gesture for the whole slab, resolved by position. What swells
            // is what opens; see DockMetrics.tileIndex for why.
            .onTapGesture(coordinateSpace: .local) { location in
                guard let item = item(at: location) else { return }
                actions.activate(item)
            }
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
        guard let pointerAxisPosition,
              let index = slotIndex(atAxisPosition: pointerAxisPosition),
              index < visibleItems.count else { return nil }
        return index
    }

    private func item(at location: CGPoint) -> DockItem? {
        let axis = configuration.edge.isVertical ? location.y : location.x
        let index = slotIndex(atAxisPosition: axis)
        let item = index.flatMap { $0 < visibleItems.count ? visibleItems[$0] : nil }

        // Synthetic clicks cannot be injected without Accessibility, so real
        // clicks are the only evidence of routing. This makes each one legible:
        //   log stream --predicate 'subsystem == "app.macdock"' --level debug
        let slot = index ?? -1
        let target = item?.name ?? "none"
        Log.panel.debug(
            """
            tap axis=\(axis, format: .fixed(precision: 1), privacy: .public) \
            slot=\(slot, privacy: .public) -> \(target, privacy: .public)
            """
        )
        return item
    }

    private func slotIndex(atAxisPosition position: CGFloat) -> Int? {
        DockMetrics.tileIndex(
            atAxisPosition: position,
            tileCount: fit.drawnTileCount,
            iconSize: fit.iconSize,
            spacing: configuration.itemSpacing
        )
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

    private func centre(ofTileAt index: Int) -> CGFloat {
        DockMetrics.tileCentre(atIndex: index, iconSize: fit.iconSize, spacing: configuration.itemSpacing)
    }

    private func scale(forTileAt index: Int) -> CGFloat {
        guard let pointerAxisPosition else { return 1 }
        let distance = abs(pointerAxisPosition - centre(ofTileAt: index))

        // The mode changes reach, not magnitude: without magnification only
        // the tile under the pointer responds, with it the neighbours do too.
        let radius = configuration.isMagnificationEnabled
            ? fit.iconSize * 2.5
            : fit.iconSize * 0.5

        return Magnification.scale(
            distance: distance,
            influenceRadius: radius,
            maximumScale: configuration.magnificationScale
        )
    }
}
