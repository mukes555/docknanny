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
    /// A tile let go beyond this dock, at a point in this view's coordinates.
    /// Another display's dock may take it, or it may be thrown away.
    var onDragOutside: (DockItem, CGPoint) -> DragReleaseOutcome = { _, _ in .cancelled }

    /// Pointer position in slot space (the resting slab's own axis), or nil
    /// when the pointer is elsewhere.
    @State var pointerSlotPosition: CGFloat?
    @State private var isDropTarget = false
    /// Apps clicked while not running. They bounce until they are.
    @State var launching: Set<String> = []
    @State var session: DockDragSession?
    @State var poof: CGPoint?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var visibleItems: [DockItem] { Array(items.prefix(fit.visibleItemCount)) }
    var geometry: DockGeometry {
        DockGeometry(fit: fit, edge: configuration.edge, spacing: configuration.itemSpacing)
    }
    var dragging: DockDragSession? { session?.isDragging == true ? session : nil }

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
        let hovered = dragging == nil ? hoveredIndex : nil
        // Magnification rests while a tile is being dragged, so the slots it
        // can land in hold still.
        let scales = DockMetrics.scales(
            pointerAxisPosition: dragging == nil ? pointerSlotPosition : nil,
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
        let hole: Int? = dragging.map { landing(for: $0).slot }

        return ZStack(alignment: .topLeading) {
            chrome(geometry.liveSlab(centres: centres, scales: scales))
            if dragging == nil {
                SectionSeparators(items: visibleItems, centres: centres, scales: scales, geometry: geometry)
            }
            SpreadLayout(
                edge: configuration.edge,
                iconSize: geometry.iconSize,
                spacing: geometry.spacing,
                centres: centres,
                scales: scales,
                skippedSlot: hole
            ) {
                tileViews(scales: scales)
            }
            liftedTile
            hoverLabel(hovered: hovered, centres: centres, scales: scales)
            if let poof {
                PoofBurst().position(poof)
            }
        }
        .frame(width: fit.panelSize.width, height: fit.panelSize.height)
        .contentShape(.rect)
        .animation(
            reduceMotion ? nil : .interactiveSpring(response: 0.14, dampingFraction: 0.86),
            value: pointerSlotPosition
        )
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: hole)
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let location):
                pointerSlotPosition = geometry.slotPosition(of: location)
                onPointerInside(true)
            case .ended:
                // Leaving the window mid-drag must not collapse it: the
                // release still has to land somewhere.
                guard dragging == nil else { return }
                pointerSlotPosition = nil
                onPointerInside(false)
            }
        }
        .gesture(pressGesture)
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

    /// The tile riding under the pointer mid-drag.
    @ViewBuilder
    private var liftedTile: some View {
        if let dragging {
            DockItemView(
                item: dragging.item,
                size: fit.iconSize * 1.08,
                edge: configuration.edge,
                indicatorStyle: .none,
                isLaunching: false,
                isLifted: true
            )
            .position(dragging.location)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func hoverLabel(hovered: Int?, centres: [CGFloat], scales: [CGFloat]) -> some View {
        if let index = hovered, index < visibleItems.count, index < centres.count, index < scales.count,
           !visibleItems[index].name.isEmpty {
            HoverLabel(text: visibleItems[index].name, centre: centres[index], scale: scales[index], geometry: geometry)
        }
    }

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

    /// Mid-drag the dragged tile leaves the row (it rides under the pointer
    /// instead) and the others are drawn at rest size around the hole.
    @ViewBuilder
    private func tileViews(scales: [CGFloat]) -> some View {
        let shown = dragging.map { DockDrag.others(than: $0.item, in: visibleItems) } ?? visibleItems
        ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
            DockItemView(
                item: item,
                size: fit.iconSize * (dragging == nil && index < scales.count ? scales[index] : 1),
                edge: configuration.edge,
                indicatorStyle: configuration.indicatorStyle,
                isLaunching: launching.contains(item.id) && !item.isRunning,
                isPressed: dragging == nil && session?.index == index
            )
        }

        if fit.overflowCount > 0 {
            OverflowTile(count: fit.overflowCount, size: fit.iconSize * (scales.last ?? 1))
        }
    }
}
