import CoreGraphics

/// Where a tile being dragged along a dock may land.
///
/// Only the pinned run at the front of the apps section can be rearranged:
/// running-but-unpinned apps sort themselves, and the section after the apps
/// has its own order. A tile that is not yet pinned may also land one past
/// the run's end, which pins it there.
enum DockDrag {
    struct Landing: Equatable {
        /// Index in display order where the dragged tile sits.
        let slot: Int
        /// The tile the dragged one goes in front of in the pin list, or nil
        /// to append.
        let before: DockItem?
    }

    /// How far past the slab a release still counts as a drop on it. Beyond
    /// this a pinned tile is being thrown away.
    static let slabTolerance: CGFloat = 48

    static func pinnedRunLength(in items: [DockItem]) -> Int {
        items.prefix { $0.section == .apps && $0.isPinned }.count
    }

    /// The slot a drag at `position` (in slot space) lands in, given the tiles
    /// on the dock including the dragged one.
    static func landing(
        forAxisPosition position: CGFloat,
        dragging item: DockItem,
        in items: [DockItem],
        iconSize: CGFloat,
        spacing: CGFloat
    ) -> Landing {
        let others = items.filter { $0.id != item.id }
        let run = pinnedRunLength(in: others)
        let raw = DockMetrics.tileIndex(
            atAxisPosition: position, tileCount: max(items.count, 1), iconSize: iconSize, spacing: spacing
        ) ?? (position < 0 ? 0 : items.count - 1)
        let slot = min(max(raw, 0), run)
        return Landing(slot: slot, before: slot < run ? others[slot] : nil)
    }

    /// The tiles as they should be drawn mid-drag: everyone else, with a
    /// hole at the landing slot for the tile riding under the pointer.
    static func others(than item: DockItem, in items: [DockItem]) -> [DockItem] {
        items.filter { $0.id != item.id }
    }
}

/// What became of a tile released off its own dock.
enum DragReleaseOutcome: Equatable {
    /// Another display's dock took it.
    case moved
    /// It was pinned and is no longer: the poof.
    case removed
    case cancelled
}
