import AppKit
import SwiftUI

/// Owns the panel for exactly one display: its size, whether it is revealed,
/// and whether it is expanded.
///
/// The window is only ever as big as what it is showing. At rest it is the
/// slab exactly; while the pointer is on the dock it grows to hold magnified
/// tiles and the hover label; hidden, it is a sliver at the screen edge. A
/// bigger window than that is an invisible margin that swallows clicks meant
/// for whatever sits beside the dock, which is how the system Dock behaves and
/// is why it resizes constantly.
///
/// Auto-hide is a frame, not a second window or a global mouse monitor: a
/// global monitor needs Accessibility permission, and an optional convenience
/// should not depend on the permission that would gate the app's core function.
@MainActor
final class DockPanelController {
    let displayID: CGDirectDisplayID

    /// How much of the panel stays reachable while hidden.
    private static let sliverThickness: CGFloat = 4
    /// Grace period before hiding again, so crossing a gap does not retract it.
    private static let concealDelay = Duration.milliseconds(450)

    private let panel: DockPanel
    /// An inert content view. AppKit keeps a window's content view sized to
    /// the window whatever its autoresizing mask says, so the hosting view's
    /// resting offset has to live on a subview AppKit does not manage.
    private let container = NSView()
    private let hosting: NSHostingView<DockContentView>
    private let actions: DockActions

    private var display: Display
    private var configuration: ResolvedDockConfiguration
    private var items: [DockItem]
    private var isRevealed: Bool
    /// Pointer is on the dock, so the window is at full size.
    private var isExpanded = false

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
        self.panel = DockPanel(contentRect: Self.fullFrame(
            for: display, configuration: configuration, fit: fit, revealed: !configuration.autoHide
        ))

        // The controller positions the hosting view itself: at rest it is
        // shifted so only the slab shows through the smaller window.
        hosting.sizingOptions = []
        hosting.autoresizingMask = []
        container.addSubview(hosting)
        panel.contentView = container
        panel.menuForRightClick = { [weak self] point in self?.menu(forRightClickInWindow: point) }
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

    // MARK: Right-click

    /// Maps a window-space point to a tile with the same slot maths the view
    /// uses for hover and taps, so the three cannot disagree. Conversion goes
    /// through the hosting view so it holds whether the window is at rest or
    /// expanded.
    private func menu(forRightClickInWindow windowPoint: NSPoint) -> NSMenu? {
        guard isRevealed else { return nil }

        let local = hosting.convert(windowPoint, from: nil)
        let topLeft = hosting.isFlipped ? local : CGPoint(x: local.x, y: hosting.bounds.height - local.y)

        let fit = Self.fit(for: display, configuration: configuration, itemCount: items.count)
        let slab = DockMetrics.slabFrame(fit: fit, edge: configuration.edge)
        let axis = configuration.edge.isVertical ? topLeft.y - slab.minY : topLeft.x - slab.minX

        guard let index = DockMetrics.tileIndex(
            atAxisPosition: axis,
            tileCount: fit.drawnTileCount,
            iconSize: fit.iconSize,
            spacing: configuration.itemSpacing
        ), index < items.count, index < fit.visibleItemCount else { return nil }

        return TileMenu.make(for: items[index], actions: actions)
    }

    /// Pops a menu up beside the dock, on the side away from the screen edge,
    /// with the given point (in the content's top-left coordinates) as the
    /// spot it grows from. AppKit nudges it back on screen if it would not fit.
    private func presentMenu(_ menu: NSMenu, from anchor: CGPoint) {
        let size = menu.size
        let gap: CGFloat = 6
        let topLeft: CGPoint = switch configuration.edge {
        case .bottom: CGPoint(x: anchor.x - size.width / 2, y: anchor.y - size.height - gap)
        case .left: CGPoint(x: anchor.x + gap, y: anchor.y - size.height / 2)
        case .right: CGPoint(x: anchor.x - size.width - gap, y: anchor.y - size.height / 2)
        }
        let point = hosting.isFlipped ? topLeft : CGPoint(x: topLeft.x, y: hosting.bounds.height - topLeft.y)
        menu.popUp(positioning: nil, at: point, in: hosting)
    }

    // MARK: Pointer

    private func pointerMovedInside(_ isInside: Bool) {
        if isRevealed, isInside != isExpanded {
            isExpanded = isInside
            render(animated: false)
        }

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
        isExpanded = false
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
            onPointerInside: { [weak self] isInside in self?.pointerMovedInside(isInside) },
            presentMenu: { [weak self] menu, anchor in self?.presentMenu(menu, from: anchor) }
        )

        let full = Self.fullFrame(for: display, configuration: configuration, fit: fit, revealed: isRevealed)
        let showsSlabOnly = isRevealed && !isExpanded
        let frame = showsSlabOnly ? Self.restFrame(within: full, fit: fit, edge: configuration.edge) : full

        // The content is always laid out at full size; at rest the window is
        // the slab's size and the content is shifted so the slab is what shows.
        hosting.frame = CGRect(
            origin: showsSlabOnly ? Self.restOffset(fit: fit, edge: configuration.edge) : .zero,
            size: full.size
        )

        guard frame != panel.frame else { return }

        // Reduce Motion reaches AppKit through NSWorkspace rather than the
        // SwiftUI environment. The dock still hides and reveals; it just cuts
        // rather than slides.
        let wantsMotion = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        guard animated, wantsMotion else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
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
        return DockMetrics.fit(itemCount: itemCount, configuration: configuration, availableLength: available)
    }

    /// The window at its largest, or the sliver when hidden.
    private static func fullFrame(
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
            lengthInset: fit.lengthHeadroom
        )
    }

    /// The resting slab's own rectangle on screen, cut out of the full frame.
    /// AppKit's origin is bottom-left, so for a bottom dock the slab shares
    /// the full frame's bottom edge.
    private static func restFrame(within full: CGRect, fit: DockFit, edge: DockEdge) -> CGRect {
        let slab = fit.slabSize
        switch edge {
        case .bottom:
            return CGRect(x: full.minX + fit.lengthHeadroom, y: full.minY, width: slab.width, height: slab.height)
        case .left:
            return CGRect(x: full.minX, y: full.minY + fit.lengthHeadroom, width: slab.width, height: slab.height)
        case .right:
            return CGRect(
                x: full.maxX - slab.width, y: full.minY + fit.lengthHeadroom,
                width: slab.width, height: slab.height
            )
        }
    }

    /// Where the full-size content sits inside the rest-size window so that
    /// the slab is the part that shows.
    private static func restOffset(fit: DockFit, edge: DockEdge) -> CGPoint {
        switch edge {
        case .bottom: CGPoint(x: -fit.lengthHeadroom, y: 0)
        case .left: CGPoint(x: 0, y: -fit.lengthHeadroom)
        case .right: CGPoint(x: -(fit.panelSize.width - fit.slabSize.width), y: -fit.lengthHeadroom)
        }
    }
}
