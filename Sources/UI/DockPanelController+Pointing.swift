import AppKit

/// Everything that maps a point to a tile: right-click menus, folder menus
/// and drops between docks. All of it goes through the hosting view's
/// coordinates, so it holds whether the window is at rest or expanded.
extension DockPanelController {
    // MARK: Right-click

    /// Maps a window-space point to a tile with the same slot maths the view
    /// uses for hover and taps, so the three cannot disagree. Conversion goes
    /// through the hosting view so it holds whether the window is at rest or
    /// expanded.
    func menu(forRightClickInWindow windowPoint: NSPoint) -> NSMenu? {
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

        let item = items[index]
        let windows = item.isRunning ? DockCommands.windows(of: item) : nil
        return TileMenu.make(for: item, actions: actions, windows: windows)
    }

    /// Pops a menu up beside the dock, on the side away from the screen edge,
    /// with the given point (in the content's top-left coordinates) as the
    /// spot it grows from. AppKit nudges it back on screen if it would not fit.
    func presentMenu(_ menu: NSMenu, from anchor: CGPoint) {
        let size = menu.size
        let gap: CGFloat = 6
        let topLeft: CGPoint = switch configuration.edge {
        case .bottom: CGPoint(x: anchor.x - size.width / 2, y: anchor.y - size.height - gap)
        case .left: CGPoint(x: anchor.x + gap, y: anchor.y - size.height / 2)
        case .right: CGPoint(x: anchor.x - size.width - gap, y: anchor.y - size.height / 2)
        }
        let point = hosting.isFlipped ? topLeft : CGPoint(x: topLeft.x, y: hosting.bounds.height - topLeft.y)
        menuTracking(true)
        menu.popUp(positioning: nil, at: point, in: hosting)
        menuTracking(false)
    }

    // MARK: Drags between docks

    /// The view's top-left coordinates, out to the screen, so the coordinator
    /// can ask every other dock whether the point is on it.
    func dragReleased(_ item: DockItem, atLocal point: CGPoint) -> DragReleaseOutcome {
        let inHosting = hosting.isFlipped ? point : CGPoint(x: point.x, y: hosting.bounds.height - point.y)
        let inWindow = hosting.convert(inHosting, to: nil)
        return onDragOutside(item, panel.convertPoint(toScreen: inWindow))
    }

    /// Where a tile dropped at a screen point would land on this dock, or nil
    /// when the point is not on it. Works from the resting geometry: a dock
    /// that is not the drag's source gets no hover, so it never expands.
    func landing(atScreenPoint point: CGPoint, for item: DockItem) -> DockDrag.Landing? {
        guard isRevealed else { return nil }

        let inHosting = hosting.convert(panel.convertPoint(fromScreen: point), from: nil)
        let topLeft = hosting.isFlipped ? inHosting : CGPoint(x: inHosting.x, y: hosting.bounds.height - inHosting.y)
        let fit = Self.fit(for: display, configuration: configuration, itemCount: items.count)
        let tolerance = DockDrag.slabTolerance
        let slab = DockMetrics.slabFrame(fit: fit, edge: configuration.edge).insetBy(dx: -tolerance, dy: -tolerance)
        guard slab.contains(topLeft) else { return nil }

        let geometry = DockGeometry(fit: fit, edge: configuration.edge, spacing: configuration.itemSpacing)
        return DockDrag.landing(
            forAxisPosition: geometry.slotPosition(of: topLeft),
            dragging: item,
            in: Array(items.prefix(fit.visibleItemCount)),
            iconSize: fit.iconSize,
            spacing: configuration.itemSpacing
        )
    }
}
