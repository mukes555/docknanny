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
        hasShadow = true
        isMovable = false
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
    }

    /// Becoming key or main is exactly the focus theft this window exists to
    /// avoid, so both are refused outright rather than merely discouraged.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
