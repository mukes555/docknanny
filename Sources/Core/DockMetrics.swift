import CoreGraphics

/// How a dock's tiles are fitted into the space one display can give them.
///
/// Sizing is computed once, here, and handed to both the window and the view.
/// Previously the panel frame was clamped to the screen while the content was
/// laid out at full size, so on a short display the end tiles rendered outside
/// the window and could not be clicked at all.
struct DockFit: Equatable, Sendable {
    /// Real application tiles that will be drawn.
    let visibleItemCount: Int
    /// Items that did not fit, represented by a single trailing tile.
    let overflowCount: Int
    /// Tile size after any shrink-to-fit. Never larger than the configured size.
    let iconSize: CGFloat
    /// The visible bar.
    let slabSize: CGSize
    /// The window, which is the slab plus room for tiles to magnify into.
    let panelSize: CGSize

    /// Tiles actually laid out, the overflow indicator included.
    var drawnTileCount: Int {
        visibleItemCount + (overflowCount > 0 ? 1 : 0)
    }
}

enum DockMetrics {
    /// Below this a tile is no longer recognisable, so the dock drops items
    /// rather than shrinking further.
    static let minimumIconSize: CGFloat = 20

    static func slabLength(tileCount: Int, iconSize: CGFloat, spacing: CGFloat) -> CGFloat {
        let tiles = CGFloat(max(tileCount, 1)) * iconSize
        let gaps = CGFloat(max(tileCount - 1, 0)) * spacing
        return tiles + gaps + spacing * 2
    }

    static func slabThickness(iconSize: CGFloat, spacing: CGFloat) -> CGFloat {
        iconSize + spacing * 2
    }

    /// Room reserved beyond the slab for the hovered tile's name.
    ///
    /// Without this the label is offset past the edge of its own window and
    /// clipped away: at default settings the panel is 65.76pt thick and the
    /// label sits at 66pt, so it never rendered once.
    static let labelClearance: CGFloat = 26

    /// How far a tile grows past the slab at its largest. One magnitude serves
    /// both modes, so the reserved room does not change when magnification is
    /// switched on: only how many tiles reach it does.
    static func headroom(iconSize: CGFloat, configuration: ResolvedDockConfiguration) -> CGFloat {
        iconSize * max(0, configuration.magnificationScale - 1)
    }

    static func fit(
        itemCount: Int,
        configuration: ResolvedDockConfiguration,
        availableLength: CGFloat
    ) -> DockFit {
        let count = max(itemCount, 0)
        let ideal = configuration.iconSize
        let spacing = configuration.itemSpacing

        let affordableIconSize = largestIconSize(
            tileCount: count,
            configuration: configuration,
            budget: availableLength
        )
        let shrunk = min(ideal, affordableIconSize)

        guard shrunk < minimumIconSize else {
            return assemble(
                visible: count,
                overflow: 0,
                iconSize: max(shrunk, minimumIconSize),
                configuration: configuration
            )
        }

        // Even at the smallest legible tile the row is too long, so items are
        // dropped and the last slot becomes a "+N" indicator.
        let affordable = largestTileCount(
            iconSize: minimumIconSize,
            spacing: spacing,
            configuration: configuration,
            budget: availableLength
        )
        let visible = max(1, affordable - 1)

        guard visible < count else {
            return assemble(
                visible: count,
                overflow: 0,
                iconSize: minimumIconSize,
                configuration: configuration
            )
        }
        return assemble(
            visible: visible,
            overflow: count - visible,
            iconSize: minimumIconSize,
            configuration: configuration
        )
    }

    /// Concentric with the tiles' own corners, which is the only radius that
    /// ever looks settled. It was a slider; nobody needs to choose this.
    static func cornerRadius(iconSize: CGFloat, configuration: ResolvedDockConfiguration) -> CGFloat {
        iconSize * 0.2237 + configuration.itemSpacing
    }

    /// Largest tile size at which `tileCount` tiles plus their magnification
    /// headroom still fit inside `budget`. Closed form, so no search loop.
    private static func largestIconSize(
        tileCount: Int,
        configuration: ResolvedDockConfiguration,
        budget: CGFloat
    ) -> CGFloat {
        let tiles = CGFloat(max(tileCount, 1))
        let growth = growthFactor(for: configuration)
        let denominator = tiles + growth
        guard denominator > 0 else { return configuration.iconSize }

        let fixed = CGFloat(max(tileCount - 1, 0)) * configuration.itemSpacing + configuration.itemSpacing * 2
        return max(0, (budget - fixed) / denominator)
    }

    private static func largestTileCount(
        iconSize: CGFloat,
        spacing: CGFloat,
        configuration: ResolvedDockConfiguration,
        budget: CGFloat
    ) -> Int {
        let growth = headroom(iconSize: iconSize, configuration: configuration)
        let usable = budget - spacing * 2 - growth + spacing
        let perTile = iconSize + spacing
        guard perTile > 0 else { return 1 }
        return max(1, Int(usable / perTile))
    }

    private static func growthFactor(for configuration: ResolvedDockConfiguration) -> CGFloat {
        max(0, configuration.magnificationScale - 1)
    }

    private static func assemble(
        visible: Int,
        overflow: Int,
        iconSize: CGFloat,
        configuration: ResolvedDockConfiguration
    ) -> DockFit {
        let tiles = visible + (overflow > 0 ? 1 : 0)
        let length = slabLength(tileCount: tiles, iconSize: iconSize, spacing: configuration.itemSpacing)
        let thickness = slabThickness(iconSize: iconSize, spacing: configuration.itemSpacing)
        let growth = headroom(iconSize: iconSize, configuration: configuration)

        let slab = configuration.edge.isVertical
            ? CGSize(width: thickness, height: length)
            : CGSize(width: length, height: thickness)

        // Magnification grows a tile on both axes, so its headroom applies to
        // both. The label only ever appears beside the dock, never past its
        // ends, so its clearance belongs to the thickness axis alone. Adding it
        // to the length is what blew the screen budget the fit function had
        // just carefully computed.
        let panel = configuration.edge.isVertical
            ? CGSize(width: slab.width + growth + labelClearance, height: slab.height + growth)
            : CGSize(width: slab.width + growth, height: slab.height + growth + labelClearance)

        return DockFit(
            visibleItemCount: visible,
            overflowCount: overflow,
            iconSize: iconSize,
            slabSize: slab,
            panelSize: panel
        )
    }

    // MARK: Slots

    /// Distance from the slab's leading edge to the centre of tile `index`,
    /// measured along whichever axis the dock runs.
    static func tileCentre(atIndex index: Int, iconSize: CGFloat, spacing: CGFloat) -> CGFloat {
        spacing + iconSize / 2 + CGFloat(index) * (iconSize + spacing)
    }

    /// Which tile's slot a point along the dock falls in.
    ///
    /// Slots are the *unscaled* layout positions, each reaching halfway into
    /// the gaps beside it. This is the only thing clicks and hover consult.
    /// Asking the view hierarchy instead was the bug: a magnified tile swells
    /// past its slot and over its neighbours, view hit-testing resolves the
    /// overlap by sibling order, and a click on the visible edge of the swollen
    /// tile opened the neighbour. Whatever a tile is doing visually, the slot
    /// under the pointer is the one that swells and the one a click means.
    static func tileIndex(
        atAxisPosition position: CGFloat,
        tileCount: Int,
        iconSize: CGFloat,
        spacing: CGFloat
    ) -> Int? {
        guard tileCount > 0 else { return nil }
        let stride = iconSize + spacing
        let firstSlotStart = spacing / 2
        let index = Int((position - firstSlotStart) / stride)
        let isInside = position >= firstSlotStart && index >= 0 && index < tileCount
        return isInside ? index : nil
    }

    /// Where the slab sits inside its panel, in top-left coordinates.
    ///
    /// The slab hugs the anchored edge; magnification headroom is split evenly
    /// along the length and stacked on the far side of the thickness. Both the
    /// view and the panel's own right-click handling read this, so neither can
    /// disagree with the other about where a tile is.
    static func slabFrame(fit: DockFit, edge: DockEdge) -> CGRect {
        let panel = fit.panelSize
        let slab = fit.slabSize

        switch edge {
        case .bottom:
            return CGRect(x: (panel.width - slab.width) / 2, y: panel.height - slab.height,
                          width: slab.width, height: slab.height)
        case .left:
            return CGRect(x: 0, y: (panel.height - slab.height) / 2,
                          width: slab.width, height: slab.height)
        case .right:
            return CGRect(x: panel.width - slab.width, y: (panel.height - slab.height) / 2,
                          width: slab.width, height: slab.height)
        }
    }
}
