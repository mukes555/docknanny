import SwiftUI

/// The contents of one dock: a row or column of tiles on a slab.
///
/// Magnified tiles push their neighbours apart, as the system Dock's do, so
/// two tiles never occupy the same pixels and a click can only ever mean one
/// thing. Every position here derives from one array of centres, handed to
/// the layout, the chrome, the separators and the label alike, so none of
/// them can disagree with each other or with the slot maths that routes clicks.
struct DockContentView: View {
    let items: [DockItem]
    let fit: DockFit
    let configuration: ResolvedDockConfiguration
    var isRevealed: Bool = true
    let actions: DockActions
    var onPointerInside: (Bool) -> Void = { _ in }
    /// Pops a menu up from a point in this view's coordinates, clear of the
    /// slab. The panel owns the AppKit side of that.
    var presentMenu: (NSMenu, CGPoint) -> Void = { _, _ in }

    /// Pointer position in slot space (the resting slab's own axis), or nil
    /// when the pointer is elsewhere.
    @State private var pointerSlotPosition: CGFloat?
    @State private var isDropTarget = false
    /// Apps clicked while not running. They bounce until they are.
    @State private var launching: Set<String> = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleItems: [DockItem] { Array(items.prefix(fit.visibleItemCount)) }
    private var geometry: DockGeometry {
        DockGeometry(fit: fit, edge: configuration.edge, spacing: configuration.itemSpacing)
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
        .dropDestination(for: URL.self) { urls, location in
            handleDrop(of: urls, at: location)
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
        let geometry = geometry
        let hovered = hoveredIndex
        let scales = DockMetrics.scales(
            pointerAxisPosition: pointerSlotPosition,
            tileCount: fit.drawnTileCount,
            iconSize: geometry.iconSize,
            spacing: geometry.spacing,
            configuration: configuration
        )
        let centres = DockMetrics.spreadCentres(
            scales: scales,
            anchor: hovered,
            iconSize: geometry.iconSize,
            spacing: geometry.spacing,
            restOrigin: fit.lengthHeadroom
        )

        return ZStack(alignment: .topLeading) {
            chrome(geometry.liveSlab(centres: centres, scales: scales))
            SectionSeparators(items: visibleItems, centres: centres, scales: scales, geometry: geometry)
            SpreadLayout(
                edge: configuration.edge,
                iconSize: geometry.iconSize,
                spacing: geometry.spacing,
                centres: centres,
                scales: scales
            ) {
                tileViews(scales: scales)
            }
            if let index = hovered, index < visibleItems.count, index < centres.count, index < scales.count,
               !visibleItems[index].name.isEmpty {
                HoverLabel(
                    text: visibleItems[index].name, centre: centres[index], scale: scales[index], geometry: geometry
                )
            }
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
                pointerSlotPosition = geometry.slotPosition(of: location)
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
                atAxisPosition: $0, tileCount: fit.drawnTileCount, iconSize: fit.iconSize, spacing: geometry.spacing
            )
        }
    }

    // MARK: Pieces

    private func chrome(_ range: ClosedRange<CGFloat>) -> some View {
        let geometry = geometry
        let length = range.upperBound - range.lowerBound
        let thickness = geometry.slabThickness
        return DockChrome(
            style: configuration.chromeStyle,
            cornerRadius: DockMetrics.cornerRadius(iconSize: geometry.iconSize, configuration: configuration),
            tint: configuration.tint
        )
        .frame(width: geometry.isVertical ? thickness : length, height: geometry.isVertical ? length : thickness)
        .overlay { dropHighlight }
        .position(geometry.point(axis: (range.lowerBound + range.upperBound) / 2, depth: thickness / 2))
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

    @ViewBuilder
    private func tileViews(scales: [CGFloat]) -> some View {
        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
            DockItemView(
                item: item,
                size: fit.iconSize * (index < scales.count ? scales[index] : 1),
                edge: configuration.edge,
                indicatorStyle: configuration.indicatorStyle,
                isLaunching: launching.contains(item.id) && !item.isRunning,
                actions: actions
            )
        }

        if fit.overflowCount > 0 {
            OverflowTile(count: fit.overflowCount, size: fit.iconSize * (scales.last ?? 1))
        }
    }

    // MARK: Clicks and drops

    /// A drop on the Trash tile deletes; anywhere else on the dock pins.
    private func handleDrop(of urls: [URL], at location: CGPoint) -> Bool {
        let files = urls.filter(\.isFileURL)
        guard !files.isEmpty else { return false }

        if let index = geometry.tileIndex(at: location, tileCount: visibleItems.count),
           case .trash = visibleItems[index].kind {
            actions.trash(files)
        } else {
            actions.drop(files)
        }
        return true
    }

    /// Resolves a tap to a slot and acts on it. Modifier keys follow the
    /// system Dock: Command reveals the app in Finder, Option activates it and
    /// hides everything else. A folder opens as a list rather than a window.
    private func handleTap(at location: CGPoint) {
        guard let index = geometry.tileIndex(at: location, tileCount: visibleItems.count) else { return }

        let item = visibleItems[index]
        let flags = NSEvent.modifierFlags
        Log.panel.debug("tap index=\(index, privacy: .public) tile=\(item.id, privacy: .public)")

        if flags.contains(.command) {
            actions.reveal(item)
            return
        }
        if let url = item.fileURL, FolderMenu.isBrowsable(url) {
            presentMenu(FolderMenu(url: url), geometry.menuAnchor(forTile: index))
            return
        }
        if item.bundleIdentifier != nil, !item.isRunning {
            launching.insert(item.id)
        }
        actions.activate(item)
        if flags.contains(.option) {
            actions.hideOthers(item)
        }
    }
}
