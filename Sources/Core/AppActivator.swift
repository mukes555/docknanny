import AppKit

/// The screen a dock lives on, for the click behaviours that act per screen.
struct DockScreen {
    /// In AppKit coordinates, as the display registry reports it.
    let frame: CGRect
    /// The part of the screen a window may use: below the menu bar, and beside
    /// the system Dock when it is on this screen.
    let visibleFrame: CGRect
    /// The primary display's height, the pivot every Accessibility
    /// coordinate turns on.
    let primaryHeight: CGFloat
}

/// Launches, focuses or hides the application behind a dock tile.
@MainActor
enum AppActivator {
    /// With `placesNewWindows`, a window the click itself brings into being,
    /// for an app that had none, opens on the screen whose dock was clicked.
    static func activate(
        bundleIdentifier: String,
        whenActive behavior: ActiveClickBehavior,
        on screen: DockScreen? = nil,
        placesNewWindows: Bool = false
    ) {
        let placement = placesNewWindows ? screen : nil

        guard let running = runningApplication(withBundleIdentifier: bundleIdentifier) else {
            launch(bundleIdentifier: bundleIdentifier, placingOn: placement)
            return
        }

        // Hiding one screen is a click on that screen's dock whether or not
        // the app is in front, since bringing back what was folded away has
        // to work from the background too.
        if behavior == .hideOnThisScreen, let screen {
            hideOrShow(running, on: screen, placingOn: placement)
            return
        }

        if running.isActive {
            applyActiveBehavior(behavior, to: running, placingOn: placement)
            return
        }
        bringForward(running, placingOn: placement)
    }

    /// The Dock's plain click on the front app is a reopen: a window when
    /// the app has none, nothing otherwise. Hiding is the one alternative.
    private static func applyActiveBehavior(
        _ behavior: ActiveClickBehavior,
        to application: NSRunningApplication,
        placingOn placement: DockScreen?
    ) {
        switch behavior {
        case .doNothing, .hideOnThisScreen:
            open(at: application.bundleURL, running: application, placingOn: placement)
        case .hide:
            application.hide()
        }
    }

    /// A click on the front app folds its windows away on this screen and
    /// leaves every other screen as it was. A click on an app in the
    /// background brings it forward instead, along with whatever was folded
    /// away here, so the same tile puts the app on this screen and takes it
    /// off again.
    private static func hideOrShow(
        _ application: NSRunningApplication,
        on screen: DockScreen,
        placingOn placement: DockScreen?
    ) {
        let plan = ScreenHider.plan(for: application.processIdentifier, on: screen)

        switch plan.action {
        case .minimize:
            // A click on an app in the background brings it forward; folding
            // away is what a click on the app you are already in means.
            guard application.isActive else {
                bringForward(application, placingOn: placement)
                return
            }
            let count = ScreenHider.apply(plan)
            Log.workspace.info("Folded \(count, privacy: .public) window(s) away on this screen")
        case .restore:
            let count = ScreenHider.apply(plan)
            bringForward(application, placingOn: placement)
            Log.workspace.info("Brought \(count, privacy: .public) window(s) back on this screen")
        case .nothing:
            bringForward(application, placingOn: placement)
        }
    }

    /// A hidden app stays hidden through a plain activation, so unhide first;
    /// then open it the way the system Dock does, which sends a reopen as well
    /// as activating. A running app with no windows makes a new one on reopen
    /// (Safari, Finder, Mail); merely activated, it would come to the front
    /// with nothing to show.
    private static func bringForward(_ application: NSRunningApplication, placingOn placement: DockScreen?) {
        if application.isHidden {
            application.unhide()
        }
        let installed = application.bundleIdentifier.flatMap {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
        open(at: application.bundleURL ?? installed, running: application, placingOn: placement)
    }

    private static func launch(bundleIdentifier: String, placingOn placement: DockScreen?) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            // Which apps a user pins is their business, so identifiers are
            // redacted in the unified log rather than published to anyone who
            // can read it.
            Log.workspace.error("No application installed for \(bundleIdentifier, privacy: .private)")
            return
        }
        open(at: url, running: nil, placingOn: placement)
    }

    /// Every click that can create a window arrives here. What the app had is
    /// noted before it is asked to open, so that afterwards only the window
    /// the click created is moved to the clicked screen.
    private static func open(at url: URL?, running: NSRunningApplication?, placingOn placement: DockScreen?) {
        guard let url else { return }

        var windowsBefore: Set<CGWindowID>?
        if placement != nil {
            windowsBefore = NewWindowPlacer.windowsBefore(opening: running)
        }
        let isLaunch = running == nil

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        Task {
            do {
                let opened = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                guard let placement, let windowsBefore else { return }
                await NewWindowPlacer.place(
                    windowsOf: opened.processIdentifier,
                    notIn: windowsBefore,
                    onto: placement,
                    launched: isLaunch
                )
            } catch {
                Log.workspace.error("Launch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// The process a tile stands for: a helper sharing the bundle identifier,
    /// or an instance on its way out, is not it.
    private static func runningApplication(withBundleIdentifier identifier: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == identifier && $0.activationPolicy == .regular && !$0.isTerminated
        }
    }
}
