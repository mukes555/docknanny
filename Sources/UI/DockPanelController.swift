import AppKit
import SwiftUI

/// Owns the panel for exactly one display.
///
/// This is the only place that turns tile count, configuration and screen
/// geometry into a window frame, which keeps that arithmetic out of both the
/// views and the app delegate. Crucially the view is handed the same ``DockFit``
/// the frame was built from, so content can never be laid out larger than the
/// window holding it.
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

        let fit = Self.fit(for: display, configuration: configuration, itemCount: items.count)
        self.hosting = NSHostingView(
            rootView: Self.content(items: items, fit: fit, configuration: configuration)
        )
        self.panel = DockPanel(
            contentRect: Self.frame(for: display, configuration: configuration, fit: fit)
        )

        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.orderFrontRegardless()

        Log.panel.info("Dock panel opened on display \(display.id, privacy: .public)")
    }

    func update(display: Display, configuration: ResolvedDockConfiguration, items: [DockItem]) {
        self.display = display
        self.configuration = configuration

        let fit = Self.fit(for: display, configuration: configuration, itemCount: items.count)
        hosting.rootView = Self.content(items: items, fit: fit, configuration: configuration)

        let frame = Self.frame(for: display, configuration: configuration, fit: fit)
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)

        // A borderless transparent window keeps the shadow it was created with
        // until told otherwise, so resizing leaves the old outline behind.
        panel.invalidateShadow()
    }

    func close() {
        panel.contentView = nil
        panel.close()
        Log.panel.info("Dock panel closed on display \(self.displayID, privacy: .public)")
    }

    private static func content(
        items: [DockItem],
        fit: DockFit,
        configuration: ResolvedDockConfiguration
    ) -> DockContentView {
        DockContentView(items: items, fit: fit, configuration: configuration) { item in
            AppActivator.activate(
                bundleIdentifier: item.id,
                whenActive: configuration.activeClickBehavior
            )
        }
    }

    private static func fit(
        for display: Display,
        configuration: ResolvedDockConfiguration,
        itemCount: Int
    ) -> DockFit {
        let available = DockPlacement.availableLength(
            againstEdge: configuration.edge,
            of: display.visibleFrame,
            margin: configuration.margin
        )
        return DockMetrics.fit(
            itemCount: itemCount,
            configuration: configuration,
            availableLength: available
        )
    }

    private static func frame(
        for display: Display,
        configuration: ResolvedDockConfiguration,
        fit: DockFit
    ) -> CGRect {
        let isVertical = configuration.edge.isVertical
        let length = isVertical ? fit.panelSize.height : fit.panelSize.width
        let thickness = isVertical ? fit.panelSize.width : fit.panelSize.height

        return DockPlacement.frame(
            againstEdge: configuration.edge,
            of: display.visibleFrame,
            thickness: thickness,
            length: length,
            margin: configuration.margin,
            alignment: configuration.alignment,
            lengthInset: DockMetrics.headroom(iconSize: fit.iconSize, configuration: configuration) / 2
        )
    }
}
