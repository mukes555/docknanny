import SwiftUI

/// What a press on the dock turns into: a tap, a drag, or a drop.
extension DockContentView {

    /// One gesture for tap, press feedback and drag: a press becomes a drag
    /// only after the pointer has travelled, and a tap only counts when the
    /// release lands on the tile that was pressed.
    var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if session == nil {
                    beginPress(at: value.startLocation)
                }
                session?.update(location: value.location)
            }
            .onEnded { value in
                guard let ended = session else { return }
                session = nil
                if ended.isDragging {
                    finishDrag(ended, at: value.location)
                } else if ended.isTap(releasedOn: tileIndex(at: value.location)) {
                    handleTap(ended.item, at: ended.index)
                }
            }
    }

    private func tileIndex(at location: CGPoint) -> Int? {
        geometry.tileIndex(at: location, tileCount: visibleItems.count)
    }

    private func beginPress(at location: CGPoint) {
        guard let index = tileIndex(at: location) else { return }
        session = DockDragSession(item: visibleItems[index], index: index, start: location)
    }

    func landing(for drag: DockDragSession) -> DockDrag.Landing {
        DockDrag.landing(
            forAxisPosition: geometry.slotPosition(of: drag.location),
            dragging: drag.item,
            in: visibleItems,
            iconSize: fit.iconSize,
            spacing: geometry.spacing
        )
    }

    /// On the slab, the tile takes the slot it was hovering. Off it, another
    /// dock may take it; a pinned tile nobody takes is thrown away with a poof.
    private func finishDrag(_ drag: DockDragSession, at location: CGPoint) {
        let tolerance = DockDrag.slabTolerance
        let slab = DockMetrics.slabFrame(fit: fit, edge: configuration.edge).insetBy(dx: -tolerance, dy: -tolerance)

        if slab.contains(location) {
            actions.move(drag.item.id, landing(for: drag).before)
        } else if onDragOutside(drag.item, location) == .removed {
            showPoof(at: location)
        }

        let bounds = CGRect(origin: .zero, size: fit.panelSize)
        if !bounds.contains(location) {
            pointerSlotPosition = nil
            onPointerInside(false)
        }
    }

    private func showPoof(at point: CGPoint) {
        // The release point is off the slab by definition and usually beyond
        // the window; the poof shows at the nearest point inside it.
        let inside = CGRect(origin: .zero, size: fit.panelSize).insetBy(dx: 14, dy: 14)
        poof = inside.isNull ? point : CGPoint(
            x: min(max(point.x, inside.minX), inside.maxX),
            y: min(max(point.y, inside.minY), inside.maxY)
        )
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            poof = nil
        }
    }

    /// Modifier keys follow the system Dock: Command reveals the app in
    /// Finder, Option activates it and hides everything else. A folder opens
    /// as a list rather than a window.
    private func handleTap(_ item: DockItem, at index: Int) {
        let flags = NSEvent.modifierFlags
        Log.panel.debug("tap index=\(index, privacy: .public) tile=\(item.id, privacy: .private)")

        if flags.contains(.command) {
            actions.reveal(item)
            return
        }
        if let url = item.fileURL, FolderMenu.isBrowsable(url) {
            presentMenu(FolderMenu(url: url), geometry.menuAnchor(forTile: index))
            return
        }
        if item.bundleIdentifier != nil, !item.isRunning {
            launching.insert(item.id)
            // An app that never comes up (not installed, or a launch the
            // person cancelled at a prompt) would otherwise bounce for ever.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                launching.remove(item.id)
            }
        }
        actions.activate(item)
        if flags.contains(.option) {
            actions.hideOthers(item)
        }
    }

    /// A drop on the Trash tile deletes; anywhere else on the dock pins. A
    /// hidden dock is an invisible sliver, and a file let go on it would be
    /// pinned, or trashed, with nothing on screen to say so.
    func handleDrop(of urls: [URL], at location: CGPoint) -> Bool {
        guard isRevealed else { return false }
        let files = urls.filter(\.isFileURL)
        guard !files.isEmpty else { return false }

        if let index = tileIndex(at: location), case .trash = visibleItems[index].kind {
            actions.trash(files)
        } else {
            actions.drop(files)
        }
        return true
    }
}
