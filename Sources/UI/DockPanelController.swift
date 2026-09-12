import AppKit
import SwiftUI

/// Owns the panel for exactly one display.
///
/// The controller is the only place that knows how tile count, configuration
/// and screen geometry combine into a window frame, which keeps that arithmetic
/// out of both the views and the app delegate.
@MainActor
final class DockPanelController {
    let displayID: CGDirectDisplayID

    private let panel: DockPanel
    private let hosting: NSHostingView<DockContentView>
    private var display: Display
    private var configuration: ResolvedDockConfiguration

    init(display: Display, configuration: ResolvedDockConfiguration, items: [DockItem]) {
        self.displayID = display.id
        self.display = display
        self.configuration = configuration

        let content = DockContentView(items: items, configuration: configuration, onActivate: Self.activate)
        self.hosting = NSHostingView(rootView: content)
        let initialFrame = Self.frame(
            for: display,
            configuration: configuration,
            itemCount: items.count
        )
        self.panel = DockPanel(contentRect: initialFrame)

        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.orderFrontRegardless()

        Log.panel.info("Dock panel opened on display \(display.id, privacy: .public)")
    }

    func update(display: Display, configuration: ResolvedDockConfiguration, items: [DockItem]) {
        self.display = display
        self.configuration = configuration

        hosting.rootView = DockContentView(
            items: items,
            configuration: configuration,
            onActivate: Self.activate
        )

        let frame = Self.frame(for: display, configuration: configuration, itemCount: items.count)
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
    }

    func close() {
        panel.orderOut(nil)
        panel.contentView = nil
        Log.panel.info("Dock panel closed on display \(self.displayID, privacy: .public)")
    }

    private static func activate(_ item: DockItem) {
        AppActivator.activate(bundleIdentifier: item.id)
    }

    private static func frame(
        for display: Display,
        configuration: ResolvedDockConfiguration,
        itemCount: Int
    ) -> CGRect {
        let size = DockMetrics.panelSize(itemCount: itemCount, configuration: configuration)
        let length = configuration.edge.isVertical ? size.height : size.width

        return DockPlacement.frame(
            againstEdge: configuration.edge,
            of: display.visibleFrame,
            thickness: configuration.edge.isVertical ? size.width : size.height,
            length: length,
            margin: configuration.margin
        )
    }
}
