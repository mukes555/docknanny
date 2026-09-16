import CoreGraphics

/// Folding an app's windows away on one screen, and bringing them back.
///
/// macOS has no per-display hide: hiding an app takes every window it has, on
/// every screen, and there is no API for anything narrower. Minimizing is per
/// window, so the same effect on one screen is a matter of choosing the right
/// windows, which is what this decides. The choosing is kept apart from the
/// doing so it can be reasoned about, and tested, without a running app.
enum ScreenHiding {
    /// One of an app's standard windows, in AppKit coordinates.
    struct Window: Equatable {
        let frame: CGRect
        let isMinimized: Bool
    }

    /// What a click on one screen's dock should do, as positions in the list
    /// of windows it was given.
    enum Action: Equatable {
        /// Fold away what can be seen on this screen.
        case minimize([Int])
        /// Bring back what was folded away here.
        case restore([Int])
        /// The app has nothing on this screen either way.
        case nothing
    }

    /// A window belongs to the screen its middle is on, so one straddling two
    /// screens is acted on once, by the dock it mostly sits over. Showing wins
    /// over hiding: with something visible here, the click folds it away, and
    /// only once nothing is left does the next click bring things back.
    static func action(for windows: [Window], onScreen screen: CGRect) -> Action {
        let here = windows.indices.filter { screen.contains(windows[$0].frame.centre) }
        let visible = here.filter { !windows[$0].isMinimized }
        guard visible.isEmpty else { return .minimize(visible) }

        let folded = here.filter { windows[$0].isMinimized }
        return folded.isEmpty ? .nothing : .restore(folded)
    }
}

private extension CGRect {
    var centre: CGPoint { CGPoint(x: midX, y: midY) }
}
