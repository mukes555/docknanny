import CoreGraphics

@testable import macdock

/// One factory for the resolved configuration every suite needs, so adding a
/// setting means updating a default here rather than in each test file.
enum TestConfiguration {
    static func make(
        edge: DockEdge = .bottom,
        alignment: DockAlignment = .center,
        iconSize: CGFloat = 48,
        itemSpacing: CGFloat = 6,
        magnified: Bool = false,
        magnificationScale: CGFloat = 1.6,
        hoverScale: CGFloat = 1.12,
        showRunningApps: Bool = true,
        autoHide: Bool = false,
        hidden: Set<String> = [],
        allowed: [String]? = nil
    ) -> ResolvedDockConfiguration {
        ResolvedDockConfiguration(
            isEnabled: true,
            edge: edge,
            alignment: alignment,
            margin: 8,
            iconSize: iconSize,
            itemSpacing: itemSpacing,
            chromeStyle: .glass,
            chromeOpacity: 1,
            cornerRadiusScale: 0.28,
            indicatorStyle: .dot,
            isMagnificationEnabled: magnified,
            magnificationScale: magnificationScale,
            hoverScale: hoverScale,
            showRunningApps: showRunningApps,
            autoHide: autoHide,
            autoHideDelay: 0.15,
            activeClickBehavior: .hide,
            hiddenBundleIdentifiers: hidden,
            allowedBundleIdentifiers: allowed
        )
    }
}
