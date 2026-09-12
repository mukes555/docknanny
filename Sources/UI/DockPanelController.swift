import AppKit
import SwiftUI

/// Owns the panel for exactly one display, including whether it is revealed.
///
/// Auto-hide is one panel with two frames rather than a second window or a
/// global mouse monitor. A global `.mouseMoved` monitor needs Accessibility
/// permission, and macdock should not make an optional convenience depend on
/// the permission that gates its core function. Concealed, the panel becomes a
/// sliver flush with the screen edge, which is exactly where a pointer travelling
/// off-screen comes to rest.
@MainActor
final class DockPanelController {
    let displayID: CGDirectDisplayID

    /// How much of the panel stays reachable while hidden.
    private static let sliverThickness: CGFloat = 4
    /// Grace period before hiding again, so crossing a gap does not retract it.
    private static let concealDelay = Duration.milliseconds(450)

    private let panel: DockPanel
    private let hosting: NSHostingView<DockContentView>
    private let actions: DockActions

    private var display: Display
    private var configuration: ResolvedDockConfiguration
    private var items: [DockItem]
    private var isRevealed: Bool

    private var revealTask: Task<Void, Never>?
    private var concealTask: Task<Void, Never>?

    init(
        display: Display,
        configuration: ResolvedDockConfiguration,
        items: [DockItem],
        actions: DockActions
    ) {
        self.displayID = display.id
        self.display = display
        self.configuration = configuration
        self.items = items
        self.actions = actions
        self.isRevealed = !configuration.autoHide

        let fit = Self.fit(for: display, configuration: configuration, itemCount: items.count)
        // Built with an inert callback because `self` is not available yet;
        // render() replaces it with the live one before the panel is shown.
        self.hosting = NSHostingView(rootView: DockContentView(
            items: items,
            fit: fit,
            configuration: configuration,
            isRevealed: !configuration.autoHide,
            actions: actions
        ))
        self.panel = DockPanel(
            contentRect: Self.frame(
                for: display,
                configuration: configuration,
                fit: fit,
                revealed: !configuration.autoHide
            )
        )

        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.orderFrontRegardless()
        render(animated: false)

        Log.panel.info("Dock panel opened on display \(display.id, privacy: .public)")
    }

    func update(display: Display, configuration: ResolvedDockConfiguration, items: [DockItem]) {
        let autoHideChanged = configuration.autoHide != self.configuration.autoHide

        self.display = display
        self.configuration = configuration
        self.items = items

        // Turning auto-hide off must not leave the dock stuck as a sliver.
        if autoHideChanged {
            isRevealed = !configuration.autoHide
        }
        render(animated: false)
    }

    func close() {
        revealTask?.cancel()
        concealTask?.cancel()
        panel.contentView = nil
        panel.close()
        Log.panel.info("Dock panel closed on display \(self.displayID, privacy: .public)")
    }

    // MARK: Reveal

    private func pointerMovedInside(_ isInside: Bool) {
        guard configuration.autoHide else { return }

        if isInside {
            scheduleReveal()
        } else {
            scheduleConceal()
        }
    }

    private func scheduleReveal() {
        concealTask?.cancel()
        concealTask = nil
        guard !isRevealed, revealTask == nil else { return }

        revealTask = Task { [weak self, delay = configuration.autoHideDelay] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.setRevealed(true)
        }
    }

    private func scheduleConceal() {
        revealTask?.cancel()
        revealTask = nil
        guard isRevealed, concealTask == nil else { return }

        concealTask = Task { [weak self] in
            try? await Task.sleep(for: Self.concealDelay)
            guard !Task.isCancelled else { return }
            self?.setRevealed(false)
        }
    }

    private func setRevealed(_ revealed: Bool) {
        revealTask = nil
        concealTask = nil
        guard revealed != isRevealed else { return }
        isRevealed = revealed
        render(animated: true)
    }

    // MARK: Rendering

    private func render(animated: Bool) {
        let fit = Self.fit(for: display, configuration: configuration, itemCount: items.count)
        hosting.rootView = DockContentView(
            items: items,
            fit: fit,
            configuration: configuration,
            isRevealed: isRevealed,
            actions: actions,
            onPointerInside: { [weak self] isInside in self?.pointerMovedInside(isInside) }
        )

        let frame = Self.frame(
            for: display,
            configuration: configuration,
            fit: fit,
            revealed: isRevealed
        )
        guard frame != panel.frame else { return }

        guard animated else {
            panel.setFrame(frame, display: true)
            panel.invalidateShadow()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
        } completionHandler: { [weak panel] in
            // A transparent borderless window keeps the shadow it was drawn
            // with, so a resize leaves the old outline behind.
            panel?.invalidateShadow()
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
        fit: DockFit,
        revealed: Bool
    ) -> CGRect {
        let isVertical = configuration.edge.isVertical
        let length = isVertical ? fit.panelSize.height : fit.panelSize.width
        let thickness = isVertical ? fit.panelSize.width : fit.panelSize.height

        // Concealed, the sliver sits flush with the screen edge: a pointer
        // pushed off-screen stops exactly there.
        return DockPlacement.frame(
            againstEdge: configuration.edge,
            of: display.visibleFrame,
            thickness: revealed ? thickness : sliverThickness,
            length: length,
            margin: revealed ? configuration.margin : 0,
            alignment: configuration.alignment,
            lengthInset: DockMetrics.headroom(iconSize: fit.iconSize, configuration: configuration) / 2
        )
    }
}
