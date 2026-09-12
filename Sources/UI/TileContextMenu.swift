import AppKit
import SwiftUI

/// Right-click handling for a dock tile.
///
/// SwiftUI's `.contextMenu` does not open from macdock's dock panel. The panel
/// refuses key status by design, which is precisely what stops it stealing
/// focus, and SwiftUI's context menu needs a window that can take first
/// responder. Verified on macOS 26.5.1 by scripting a right-click at a tile:
/// the modifier was attached, the click landed, no menu appeared.
///
/// `NSMenu.popUpContextMenu` runs its own event-tracking loop and does not care
/// whether the window is key, which the SwiftUI modifier may well need. The
/// view sits *behind* the tile: SwiftUI's tap gesture and hover tracking do not
/// consume right-clicks, so the event falls through to this responder without
/// any hit-test trickery.
struct TileContextMenu: NSViewRepresentable {
    let build: () -> NSMenu

    func makeNSView(context: Context) -> NSView {
        let view = RightClickView()
        view.build = build
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? RightClickView)?.build = build
    }
}

private final class RightClickView: NSView {
    var build: (() -> NSMenu)?

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = build?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

}

/// An `NSMenuItem` that runs a closure, so menus can be built inline instead of
/// routing every entry through a selector on some controller.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("ClosureMenuItem is built in code, never from a nib")
    }

    @objc
    private func fire() {
        handler()
    }
}
