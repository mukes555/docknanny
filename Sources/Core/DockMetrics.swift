import CoreGraphics

/// How large a dock panel needs to be for the tiles it holds.
///
/// Pure arithmetic, kept apart from the views so panel sizing can be tested
/// without a screen attached.
enum DockMetrics {
    static func panelSize(itemCount: Int, configuration: ResolvedDockConfiguration) -> CGSize {
        let padding = configuration.itemSpacing
        let tiles = CGFloat(max(itemCount, 1)) * configuration.iconSize
        let gaps = CGFloat(max(itemCount - 1, 0)) * configuration.itemSpacing

        let length = tiles + gaps + padding * 2
        let thickness = configuration.iconSize + padding * 2

        return configuration.edge.isVertical
            ? CGSize(width: thickness, height: length)
            : CGSize(width: length, height: thickness)
    }

    static func cornerRadius(for configuration: ResolvedDockConfiguration) -> CGFloat {
        (configuration.iconSize + configuration.itemSpacing * 2) * 0.28
    }
}
