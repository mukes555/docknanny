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

    /// How far a tile grows past the slab at its largest.
    static func headroom(iconSize: CGFloat, configuration: ResolvedDockConfiguration) -> CGFloat {
        let peak = configuration.isMagnificationEnabled
            ? configuration.magnificationScale
            : configuration.hoverScale
        return iconSize * max(0, peak - 1)
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

    static func cornerRadius(iconSize: CGFloat, configuration: ResolvedDockConfiguration) -> CGFloat {
        slabThickness(iconSize: iconSize, spacing: configuration.itemSpacing) * configuration.cornerRadiusScale
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
        let peak = configuration.isMagnificationEnabled
            ? configuration.magnificationScale
            : configuration.hoverScale
        return max(0, peak - 1)
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
        let panel = CGSize(width: slab.width + growth, height: slab.height + growth)

        return DockFit(
            visibleItemCount: visible,
            overflowCount: overflow,
            iconSize: iconSize,
            slabSize: slab,
            panelSize: panel
        )
    }
}
