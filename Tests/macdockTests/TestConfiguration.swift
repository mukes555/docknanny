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
        showRunningApps: Bool = true,
        autoHide: Bool = false,
        hidden: Set<String> = [],
        pinned: [String] = [],
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
            indicatorStyle: .dot,
            tint: .none,
            isMagnificationEnabled: magnified,
            magnificationScale: magnificationScale,
            showRunningApps: showRunningApps,
            autoHide: autoHide,
            autoHideDelay: 0.15,
            activeClickBehavior: .hide,
            pinnedBundleIdentifiers: pinned,
            hiddenBundleIdentifiers: hidden,
            allowedBundleIdentifiers: allowed
        )
    }
}
