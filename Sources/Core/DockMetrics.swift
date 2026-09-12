import CoreGraphics

/// How large a dock panel needs to be for the tiles it holds.
///
/// A magnifying dock needs room for tiles to swell *beyond* the slab they sit
/// on, the way the system Dock does. The panel is therefore sized as slab plus
/// headroom, and the slab itself is drawn only against the anchored edge.
enum DockMetrics {
    static func slabThickness(for configuration: ResolvedDockConfiguration) -> CGFloat {
        configuration.iconSize + configuration.itemSpacing * 2
    }

    static func slabLength(itemCount: Int, configuration: ResolvedDockConfiguration) -> CGFloat {
        let padding = configuration.itemSpacing
        let tiles = CGFloat(max(itemCount, 1)) * configuration.iconSize
        let gaps = CGFloat(max(itemCount - 1, 0)) * configuration.itemSpacing
        return tiles + gaps + padding * 2
    }

    /// Space a tile needs to grow into at its largest.
    static func headroom(for configuration: ResolvedDockConfiguration) -> CGFloat {
        let peak = configuration.isMagnificationEnabled
            ? configuration.magnificationScale
            : configuration.hoverScale
        return configuration.iconSize * max(0, peak - 1)
    }

    static func slabSize(itemCount: Int, configuration: ResolvedDockConfiguration) -> CGSize {
        let length = slabLength(itemCount: itemCount, configuration: configuration)
        let thickness = slabThickness(for: configuration)

        return configuration.edge.isVertical
            ? CGSize(width: thickness, height: length)
            : CGSize(width: length, height: thickness)
    }

    static func panelSize(itemCount: Int, configuration: ResolvedDockConfiguration) -> CGSize {
        let slab = slabSize(itemCount: itemCount, configuration: configuration)
        let growth = headroom(for: configuration)

        return configuration.edge.isVertical
            ? CGSize(width: slab.width + growth, height: slab.height + growth)
            : CGSize(width: slab.width + growth, height: slab.height + growth)
    }

    static func cornerRadius(for configuration: ResolvedDockConfiguration) -> CGFloat {
        slabThickness(for: configuration) * configuration.cornerRadiusScale
    }
}
