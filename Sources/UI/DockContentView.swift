import SwiftUI

/// The contents of one dock: a row or column of tiles on a slab.
///
/// Magnified tiles push their neighbours apart, as the system Dock's do, so
/// two tiles never occupy the same pixels and a click can only ever mean one
/// thing. Every position here derives from one array of centres, handed to
/// the layout, the chrome, the separator and the label alike, so none of them
/// can disagree with each other or with the slot maths that routes clicks.
struct DockContentView: View {
    let items: [DockItem]
    let fit: DockFit
    let configuration: ResolvedDockConfiguration
    var isRevealed: Bool = true
    let actions: DockActions
    var onPointerInside: (Bool) -> Void = { _ in }

    /// Pointer position in slot space (the resting slab's own axis), or nil
    /// when the pointer is elsewhere.
    @State private var pointerSlotPosition: CGFloat?
    @State private var isDropTarget = false
    /// Apps clicked while not running. They bounce until they are.
    @State private var launching: Set<String> = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleItems: [DockItem] { Array(items.prefix(fit.visibleItemCount)) }
    private var isVertical: Bool { configuration.edge.isVertical }
    private var spacing: CGFloat { configuration.itemSpacing }
    private var iconSize: CGFloat { fit.iconSize }
    private var slabThickness: CGFloat { DockMetrics.slabThickness(iconSize: iconSize, spacing: spacing) }
    private var panelThickness: CGFloat { isVertical ? fit.panelSize.width : fit.panelSize.height }

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

    /// The slab hugs the screen edge; the headroom sits on the other side.
    private var anchorAlignment: Alignment {
        switch configuration.edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
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
        let hovered = hoveredIndex
        let scales = DockMetrics.scales(
            pointerAxisPosition: pointerSlotPosition,
            tileCount: fit.drawnTileCount,
            iconSize: iconSize,
            spacing: spacing,
            configuration: configuration
        )
        let centres = DockMetrics.spreadCentres(
            scales: scales,
            anchor: hovered,
            iconSize: iconSize,
            spacing: spacing,
            restOrigin: fit.lengthHeadroom
        )

        return ZStack(alignment: .topLeading) {
            chrome(liveSlab(centres: centres, scales: scales))
            separator(centres: centres, scales: scales)
            SpreadLayout(
                edge: configuration.edge,
                iconSize: iconSize,
                spacing: spacing,
                centres: centres,
                scales: scales
            ) {
                tileViews(scales: scales)
            }
            label(hovered: hovered, centres: centres, scales: scales)
        }
        .frame(width: fit.panelSize.width, height: fit.panelSize.height)
        .contentShape(.rect)
        .animation(
            reduceMotion ? nil : .interactiveSpring(response: 0.14, dampingFraction: 0.86),
            value: pointerSlotPosition
        )
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let location):
                pointerSlotPosition = axis(of: location) - fit.lengthHeadroom
                onPointerInside(true)
            case .ended:
                pointerSlotPosition = nil
                onPointerInside(false)
            }
        }
        .onTapGesture(coordinateSpace: .local) { location in
            handleTap(at: location)
        }
        .onChange(of: items) { _, current in
            launching.subtract(current.filter(\.isRunning).map(\.id))
        }
    }

    private var hoveredIndex: Int? {
        pointerSlotPosition.flatMap {
            DockMetrics.tileIndex(
                atAxisPosition: $0, tileCount: fit.drawnTileCount, iconSize: iconSize, spacing: spacing
            )
        }
    }

    // MARK: Pieces

    private func chrome(_ range: ClosedRange<CGFloat>) -> some View {
        let length = range.upperBound - range.lowerBound
        return DockChrome(
            style: configuration.chromeStyle,
            cornerRadius: DockMetrics.cornerRadius(iconSize: iconSize, configuration: configuration),
            tint: configuration.tint
        )
        .frame(width: isVertical ? slabThickness : length, height: isVertical ? length : slabThickness)
        .overlay { dropHighlight }
        .position(point(axis: (range.lowerBound + range.upperBound) / 2, depth: slabThickness / 2))
    }

    /// Dropping an app onto a dock pins it. Without a target highlight the drag
    /// gives no sign it will land.
    @ViewBuilder
    private var dropHighlight: some View {
        if isDropTarget {
            RoundedRectangle(
                cornerRadius: DockMetrics.cornerRadius(iconSize: iconSize, configuration: configuration),
                style: .continuous
            )
            .strokeBorder(.tint, lineWidth: 2)
        }
    }

    /// The hairline between pinned tiles and merely-running ones, placed in the
    /// gap wherever the gap currently is.
    @ViewBuilder
    private func separator(centres: [CGFloat], scales: [CGFloat]) -> some View {
        if let boundary = visibleItems.firstIndex(where: { !$0.isPinned }),
           boundary > 0, boundary < centres.count, boundary < scales.count {
            let before = centres[boundary - 1] + iconSize * scales[boundary - 1] / 2
            let after = centres[boundary] - iconSize * scales[boundary] / 2
            let length = iconSize * 0.8

            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(width: isVertical ? length : 1, height: isVertical ? 1 : length)
                .position(point(axis: (before + after) / 2, depth: slabThickness / 2))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func tileViews(scales: [CGFloat]) -> some View {
        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
            DockItemView(
                item: item,
                size: iconSize * (index < scales.count ? scales[index] : 1),
                edge: configuration.edge,
                indicatorStyle: configuration.indicatorStyle,
                isLaunching: launching.contains(item.id) && !item.isRunning,
                actions: actions
            )
        }

        if fit.overflowCount > 0 {
            overflowTile(size: iconSize * (scales.last ?? 1))
        }
    }

    /// Shown instead of the last tile when the display is too short to hold
    /// every item, so nothing is dropped without the user being told.
    private func overflowTile(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(.secondary.opacity(0.22))
            .frame(width: size, height: size)
            .overlay {
                Text("+\(fit.overflowCount)")
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.5)
            }
            .help("\(fit.overflowCount) more apps do not fit on this display")
            .accessibilityLabel("\(fit.overflowCount) more apps")
    }

    /// The name rides clear of the icon at whatever size the icon currently is,
    /// the way the system Dock's does.
    @ViewBuilder
    private func label(hovered: Int?, centres: [CGFloat], scales: [CGFloat]) -> some View {
        if let index = hovered, index < visibleItems.count, index < centres.count, index < scales.count {
            let iconReach = slabThickness - spacing + iconSize * scales[index]
            let depth = iconReach + (isVertical ? 8 + DockMetrics.labelMaximumWidth / 2 : 14)

            TileLabel(text: visibleItems[index].name)
                .frame(width: isVertical ? DockMetrics.labelMaximumWidth : nil, alignment: labelAlignment)
                .position(point(axis: centres[index], depth: depth))
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private var labelAlignment: Alignment {
        switch configuration.edge {
        case .bottom: .center
        case .left: .leading
        case .right: .trailing
        }
    }

    // MARK: Geometry

    private func axis(of point: CGPoint) -> CGFloat {
        isVertical ? point.y : point.x
    }

    /// Panel coordinates for a point given along the dock's axis and by its
    /// distance in from the screen edge.
    private func point(axis: CGFloat, depth: CGFloat) -> CGPoint {
        switch configuration.edge {
        case .bottom: CGPoint(x: axis, y: panelThickness - depth)
        case .left: CGPoint(x: depth, y: axis)
        case .right: CGPoint(x: panelThickness - depth, y: axis)
        }
    }

    /// Where the glass currently starts and ends along the axis, following the
    /// tiles as they spread.
    private func liveSlab(centres: [CGFloat], scales: [CGFloat]) -> ClosedRange<CGFloat> {
        guard let first = centres.first, let last = centres.last,
              let firstScale = scales.first, let lastScale = scales.last else {
            let restLength = isVertical ? fit.slabSize.height : fit.slabSize.width
            return fit.lengthHeadroom...(fit.lengthHeadroom + restLength)
        }
        let start = first - iconSize * firstScale / 2 - spacing
        let end = last + iconSize * lastScale / 2 + spacing
        return min(start, end)...max(start, end)
    }

    // MARK: Clicks

    /// Resolves a tap to a slot and acts on it. Modifier keys follow the
    /// system Dock: Command reveals the app in Finder, Option activates it and
    /// hides everything else.
    private func handleTap(at location: CGPoint) {
        let slot = axis(of: location) - fit.lengthHeadroom
        guard let index = DockMetrics.tileIndex(
            atAxisPosition: slot, tileCount: fit.drawnTileCount, iconSize: iconSize, spacing: spacing
        ), index < visibleItems.count else { return }

        let item = visibleItems[index]
        let flags = NSEvent.modifierFlags
        Log.panel.debug(
            "tap slot=\(slot, privacy: .public) index=\(index, privacy: .public) app=\(item.id, privacy: .public)"
        )

        if flags.contains(.command) {
            actions.reveal(item)
            return
        }
        if !item.isRunning {
            launching.insert(item.id)
        }
        actions.activate(item)
        if flags.contains(.option) {
            actions.hideOthers(item)
        }
    }
}
