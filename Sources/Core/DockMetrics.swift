import CoreGraphics

/// How a dock's tiles are fitted into the space one display can give them.
///
/// Sizing is computed once, here, and handed to both the window and the view.
/// The panel is larger than the visible slab: magnified tiles need room to
/// swell on the thickness axis and to push their neighbours along the length
/// axis, and the hovered tile's name needs room beyond that.
struct DockFit: Equatable, Sendable {
    /// Real application tiles that will be drawn.
    let visibleItemCount: Int
    /// Items that did not fit, represented by a single trailing tile.
    let overflowCount: Int
    /// Tile size after any shrink-to-fit. Never larger than the configured size.
    let iconSize: CGFloat
    /// The visible bar at rest.
    let slabSize: CGSize
    /// The window at its largest: slab plus room to magnify, spread and label.
    let panelSize: CGSize
    /// Transparent room at each end of the resting slab, for tiles pushed
    /// outward by magnification. Also where slot space begins in panel space.
    let lengthHeadroom: CGFloat

    /// Tiles actually laid out, the overflow indicator included.
    var drawnTileCount: Int {
        visibleItemCount + (overflowCount > 0 ? 1 : 0)
    }
}

enum DockMetrics {
    /// Below this a tile is no longer recognisable, so the dock drops items
    /// rather than shrinking further.
    static let minimumIconSize: CGFloat = 20

    /// The widest a hover label may be before it truncates.
    static let labelMaximumWidth: CGFloat = 160

    /// Room reserved beyond the slab, on the thickness axis, for the hovered
    /// tile's name. Beside a vertical dock the label runs sideways, so it
    /// needs the width of a name rather than the height of one.
    static func labelClearance(for edge: DockEdge) -> CGFloat {
        edge.isVertical ? labelMaximumWidth + 14 : 32
    }

    // MARK: Resting geometry

    static func slabLength(tileCount: Int, iconSize: CGFloat, spacing: CGFloat) -> CGFloat {
        let tiles = CGFloat(max(tileCount, 1)) * iconSize
        let gaps = CGFloat(max(tileCount - 1, 0)) * spacing
        return tiles + gaps + spacing * 2
    }

    static func slabThickness(iconSize: CGFloat, spacing: CGFloat) -> CGFloat {
        iconSize + spacing * 2
    }

    /// Distance from the slab's leading edge to the centre of tile `index`
    /// at rest, measured along whichever axis the dock runs.
    static func tileCentre(atIndex index: Int, iconSize: CGFloat, spacing: CGFloat) -> CGFloat {
        spacing + iconSize / 2 + CGFloat(index) * (iconSize + spacing)
    }

    /// Which tile's slot a point along the dock's axis falls in, or nil when
    /// it lies past either end.
    ///
    /// Slots are the RESTING positions and never move. Whatever a tile is
    /// doing visually, the slot under the pointer is the tile that swells and
    /// the tile a click means; ``spreadCentres`` anchors the layout on that
    /// same slot so the two can never disagree.
    static func tileIndex(
        atAxisPosition position: CGFloat,
        tileCount: Int,
        iconSize: CGFloat,
        spacing: CGFloat
    ) -> Int? {
        guard tileCount > 0 else { return nil }
        let length = slabLength(tileCount: tileCount, iconSize: iconSize, spacing: spacing)
        guard position >= 0, position <= length else { return nil }

        // The slab's own end padding is claimed by the end tiles: a magnified
        // first tile visibly extends into it, and a click there means that tile.
        let stride = iconSize + spacing
        let index = Int(((position - spacing / 2) / stride).rounded(.down))
        return min(max(index, 0), tileCount - 1)
    }

    // MARK: Magnification

    /// How far from the pointer the effect reaches. Magnification mode swells
    /// the neighbours too; hover mode reaches only the tile under the pointer.
    static func influenceRadius(iconSize: CGFloat, configuration: ResolvedDockConfiguration) -> CGFloat {
        configuration.isMagnificationEnabled ? iconSize * 2.5 : iconSize * 0.5
    }

    /// Per-tile scale for a pointer at `pointerAxisPosition` in slot space.
    static func scales(
        pointerAxisPosition: CGFloat?,
        tileCount: Int,
        iconSize: CGFloat,
        spacing: CGFloat,
        configuration: ResolvedDockConfiguration
    ) -> [CGFloat] {
        guard let pointer = pointerAxisPosition else {
            return Array(repeating: 1, count: tileCount)
        }
        let radius = influenceRadius(iconSize: iconSize, configuration: configuration)
        return (0..<tileCount).map { index in
            Magnification.scale(
                distance: abs(pointer - tileCentre(atIndex: index, iconSize: iconSize, spacing: spacing)),
                influenceRadius: radius,
                maximumScale: configuration.magnificationScale
            )
        }
    }

    /// How far a single tile grows past the slab on the thickness axis.
    static func headroom(iconSize: CGFloat, configuration: ResolvedDockConfiguration) -> CGFloat {
        iconSize * max(0, configuration.magnificationScale - 1)
    }

    /// The most the dock can lengthen with the pointer anywhere along it.
    ///
    /// With magnification the neighbours swell too, so the dock grows by more
    /// than one tile's worth. Found by scanning pointer offsets across one
    /// stride and summing every tile's growth, which is exact for the curve in
    /// use rather than a constant that would go stale if the curve changed.
    static func lengthHeadroom(
        iconSize: CGFloat,
        spacing: CGFloat,
        configuration: ResolvedDockConfiguration
    ) -> CGFloat {
        let peak = configuration.magnificationScale
        guard peak > 1 else { return 0 }

        let radius = influenceRadius(iconSize: iconSize, configuration: configuration)
        let stride = iconSize + spacing
        let reach = Int((radius / stride).rounded(.up)) + 1
        let samples = 24

        var worst: CGFloat = 0
        for step in 0...samples {
            let offset = stride * CGFloat(step) / CGFloat(samples)
            var total: CGFloat = 0
            for tile in -reach...reach {
                let distance = abs(CGFloat(tile) * stride - offset)
                total += Magnification.scale(distance: distance, influenceRadius: radius, maximumScale: peak) - 1
            }
            worst = max(worst, total)
        }
        return worst * iconSize
    }

    /// Centres of every drawn tile along the axis, in panel coordinates, with
    /// magnified tiles pushing their neighbours apart so nothing overlaps.
    ///
    /// The anchored tile keeps its resting centre and everything else moves
    /// away from it. That is what stops the dock sliding under a pointer that
    /// is holding still, and it is what makes the slot under the pointer also
    /// the tile visibly under it.
    static func spreadCentres(
        scales: [CGFloat],
        anchor: Int?,
        iconSize: CGFloat,
        spacing: CGFloat,
        restOrigin: CGFloat
    ) -> [CGFloat] {
        let count = scales.count
        guard count > 0 else { return [] }

        let pivot = min(max(anchor ?? 0, 0), count - 1)
        var centres = [CGFloat](repeating: 0, count: count)
        centres[pivot] = restOrigin + tileCentre(atIndex: pivot, iconSize: iconSize, spacing: spacing)

        var index = pivot + 1
        while index < count {
            let previous = iconSize * scales[index - 1] / 2
            let current = iconSize * scales[index] / 2
            centres[index] = centres[index - 1] + previous + spacing + current
            index += 1
        }

        index = pivot - 1
        while index >= 0 {
            let next = iconSize * scales[index + 1] / 2
            let current = iconSize * scales[index] / 2
            centres[index] = centres[index + 1] - next - spacing - current
            index -= 1
        }
        return centres
    }

    // MARK: Frames

    /// The resting slab inside the panel, in top-left panel coordinates.
    static func slabFrame(fit: DockFit, edge: DockEdge) -> CGRect {
        let panel = fit.panelSize
        let slab = fit.slabSize
        switch edge {
        case .bottom:
            return CGRect(x: fit.lengthHeadroom, y: panel.height - slab.height, width: slab.width, height: slab.height)
        case .left:
            return CGRect(x: 0, y: fit.lengthHeadroom, width: slab.width, height: slab.height)
        case .right:
            return CGRect(x: panel.width - slab.width, y: fit.lengthHeadroom, width: slab.width, height: slab.height)
        }
    }

    static func fit(
        itemCount: Int,
        configuration: ResolvedDockConfiguration,
        availableLength: CGFloat
    ) -> DockFit {
        let count = max(itemCount, 0)
        let spacing = configuration.itemSpacing
        let drawnAll = max(count, 1)

        // Shrink first: a smaller dock is better than a dock missing apps.
        var iconSize = configuration.iconSize
        while iconSize > minimumIconSize,
              panelLength(drawnTiles: drawnAll, iconSize: iconSize, spacing: spacing, configuration: configuration)
                > availableLength {
            iconSize = max(minimumIconSize, iconSize - 1)
        }

        if panelLength(drawnTiles: drawnAll, iconSize: iconSize, spacing: spacing, configuration: configuration)
            <= availableLength {
            return assemble(visible: count, overflow: 0, iconSize: iconSize, configuration: configuration)
        }

        // Even the smallest legible tile is too long a row, so items are
        // dropped and the last slot becomes a "+N" indicator.
        var drawn = drawnAll
        while drawn > 1,
              panelLength(drawnTiles: drawn, iconSize: minimumIconSize, spacing: spacing, configuration: configuration)
                > availableLength {
            drawn -= 1
        }
        let visible = max(1, drawn - 1)
        guard visible < count else {
            return assemble(visible: count, overflow: 0, iconSize: minimumIconSize, configuration: configuration)
        }
        return assemble(
            visible: visible, overflow: count - visible, iconSize: minimumIconSize, configuration: configuration
        )
    }

    /// Concentric with the tiles' own corners, which is the only radius that
    /// ever looks settled.
    static func cornerRadius(iconSize: CGFloat, configuration: ResolvedDockConfiguration) -> CGFloat {
        iconSize * 0.2237 + configuration.itemSpacing
    }

    private static func panelLength(
        drawnTiles: Int,
        iconSize: CGFloat,
        spacing: CGFloat,
        configuration: ResolvedDockConfiguration
    ) -> CGFloat {
        slabLength(tileCount: drawnTiles, iconSize: iconSize, spacing: spacing)
            + 2 * lengthHeadroom(iconSize: iconSize, spacing: spacing, configuration: configuration)
    }

    private static func assemble(
        visible: Int,
        overflow: Int,
        iconSize: CGFloat,
        configuration: ResolvedDockConfiguration
    ) -> DockFit {
        let spacing = configuration.itemSpacing
        let tiles = visible + (overflow > 0 ? 1 : 0)
        let length = slabLength(tileCount: tiles, iconSize: iconSize, spacing: spacing)
        let thickness = slabThickness(iconSize: iconSize, spacing: spacing)
        let alongEnds = lengthHeadroom(iconSize: iconSize, spacing: spacing, configuration: configuration)
        let beyondSlab = headroom(iconSize: iconSize, configuration: configuration)
            + labelClearance(for: configuration.edge)

        let slab = configuration.edge.isVertical
            ? CGSize(width: thickness, height: length)
            : CGSize(width: length, height: thickness)
        let panel = configuration.edge.isVertical
            ? CGSize(width: thickness + beyondSlab, height: length + alongEnds * 2)
            : CGSize(width: length + alongEnds * 2, height: thickness + beyondSlab)

        return DockFit(
            visibleItemCount: visible,
            overflowCount: overflow,
            iconSize: iconSize,
            slabSize: slab,
            panelSize: panel,
            lengthHeadroom: alongEnds
        )
    }
}
