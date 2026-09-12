import AppKit

/// The window a dock lives in.
///
/// This configuration is the foundation the whole product rests on and was
/// validated in Phase 0. Borderless plus non-activating is what makes clicking
/// a dock icon leave focus where it was, and `canJoinAllSpaces` is what keeps
/// the dock present when the user switches Space.
final class DockPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        // The slab draws its own shadow, which follows its rounded outline. A
        // window shadow would follow the rectangular frame instead, boxing the
        // transparent headroom above the dock.
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false

        // NSWindow defaults this to true for programmatically created windows.
        // The controller holds the panel in a stored property, so letting AppKit
        // release it on close is a use-after-free waiting for a display to be
        // unplugged.
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    /// Becoming key or main is exactly the focus theft this window exists to
    /// avoid, so both are refused outright rather than merely discouraged.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
