import CoreGraphics

/// One press on a tile, from mouse-down to release.
///
/// A press is a tap until the pointer travels far enough to mean a drag.
/// Only app tiles drag; a spacer, a folder or the Trash just shows the press.
struct DockDragSession {
    let item: DockItem
    /// The tile's index when the press began.
    let index: Int
    let start: CGPoint
    private(set) var location: CGPoint
    private(set) var isDragging = false

    private static let dragThreshold: CGFloat = 6

    init(item: DockItem, index: Int, start: CGPoint) {
        self.item = item
        self.index = index
        self.start = start
        self.location = start
    }

    private var canDrag: Bool { item.bundleIdentifier != nil }

    mutating func update(location: CGPoint) {
        self.location = location
        guard canDrag, !isDragging else { return }
        isDragging = hypot(location.x - start.x, location.y - start.y) > Self.dragThreshold
    }

    /// True when the release lands on the same tile the press started on, so
    /// pressing, sliding off and letting go does nothing, as in the Dock.
    func isTap(releasedOn index: Int?) -> Bool {
        !isDragging && index == self.index
    }
}
