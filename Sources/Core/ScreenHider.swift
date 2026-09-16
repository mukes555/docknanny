import AppKit
import ApplicationServices

/// Folding an app's windows away on one screen and bringing them back: the
/// doing, beside ``ScreenHiding``'s deciding.
///
/// Kept apart from the click that asks for it so the same steps can be run,
/// and watched, by the `--probe-hide` diagnostic.
@MainActor
enum ScreenHider {
    /// What a click would do to an app on one screen, and the windows it
    /// would do it to.
    struct Plan {
        let action: ScreenHiding.Action
        /// Every standard window of the app that could be placed on a screen,
        /// in AppKit coordinates, in step with ``elements``.
        let windows: [ScreenHiding.Window]
        let elements: [AXUIElement]

        /// Positions in ``windows`` the action names, in any of its forms.
        var targets: [Int] {
            switch action {
            case .minimize(let positions), .restore(let positions): positions
            case .nothing: []
            }
        }
    }

    /// Where each window is, and what a click would do about it. A window
    /// neither source can place belongs to no screen, so no screen's dock
    /// acts on it and it is left out of the plan entirely.
    static func plan(for pid: pid_t, on screen: DockScreen) -> Plan {
        let bounds = WindowServer.everyWindowBounds(ofProcess: pid)

        var elements: [AXUIElement] = []
        var windows: [ScreenHiding.Window] = []
        for window in AppWindows.standardWindows(processIdentifier: pid) {
            let server = PrivateSymbols.windowNumber(of: window.element).flatMap { bounds[$0] }
            guard let reported = position(
                ofMinimized: window.isMinimized, server: server, app: window.reportedFrame
            ) else { continue }
            elements.append(window.element)
            windows.append(ScreenHiding.Window(
                frame: Coordinates.appKitRect(fromAccessibility: reported, primaryHeight: screen.primaryHeight),
                isMinimized: window.isMinimized
            ))
        }

        return Plan(
            action: ScreenHiding.action(for: windows, onScreen: screen.frame),
            windows: windows,
            elements: elements
        )
    }

    /// Which source to believe about where a window is.
    ///
    /// For a window on screen the window server is the truth, since an app can
    /// report whatever frame it likes and iTerm2 reports the last one it was
    /// asked to take. For a window folded away it is the other way round: the
    /// window server describes the thumbnail in the Dock, which sits on
    /// whichever screen the Dock is on, while the app still knows where the
    /// window itself belongs. Measured: a second after folding, the server
    /// said 23,250 177x85 and the app said 195,638 673x439, and only the
    /// second answer says which screen's dock should bring it back.
    static func position(ofMinimized isMinimized: Bool, server: CGRect?, app: CGRect?) -> CGRect? {
        isMinimized ? (app ?? server) : (server ?? app)
    }

    /// Carries a plan out, and says how many windows it touched.
    @discardableResult
    static func apply(_ plan: Plan) -> Int {
        switch plan.action {
        case .minimize(let positions):
            for position in positions {
                AppWindows.setMinimized(true, of: plan.elements[position])
            }
            return positions.count
        case .restore(let positions):
            for position in positions {
                AppWindows.setMinimized(false, of: plan.elements[position])
            }
            return positions.count
        case .nothing:
            return 0
        }
    }
}
