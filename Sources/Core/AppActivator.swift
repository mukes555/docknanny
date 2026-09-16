import AppKit

/// The screen a dock lives on, for the click behaviours that act per screen.
struct DockScreen {
    /// In AppKit coordinates, as the display registry reports it.
    let frame: CGRect
    /// The primary display's height, the pivot every Accessibility
    /// coordinate turns on.
    let primaryHeight: CGFloat
}

/// Launches, focuses or hides the application behind a dock tile.
@MainActor
enum AppActivator {
    static func activate(
        bundleIdentifier: String,
        whenActive behavior: ActiveClickBehavior,
        on screen: DockScreen? = nil
    ) {
        guard let running = runningApplication(withBundleIdentifier: bundleIdentifier) else {
            launch(bundleIdentifier: bundleIdentifier)
            return
        }

        // Hiding one screen is a click on that screen's dock whether or not
        // the app is in front, since bringing back what was folded away has
        // to work from the background too.
        if behavior == .hideOnThisScreen, let screen {
            hideOrShow(running, on: screen)
            return
        }

        if running.isActive {
            applyActiveBehavior(behavior, to: running)
            return
        }
        bringForward(running, bundleIdentifier: bundleIdentifier)
    }

    /// The Dock's plain click on the front app is a reopen: a window when
    /// the app has none, nothing otherwise. Hiding is the one alternative.
    private static func applyActiveBehavior(
        _ behavior: ActiveClickBehavior,
        to application: NSRunningApplication
    ) {
        switch behavior {
        case .doNothing, .hideOnThisScreen:
            open(at: application.bundleURL)
        case .hide:
            application.hide()
        }
    }

    /// A click on the front app folds its windows away on this screen and
    /// leaves every other screen as it was. A click on an app in the
    /// background brings it forward instead, along with whatever was folded
    /// away here, so the same tile puts the app on this screen and takes it
    /// off again.
    private static func hideOrShow(_ application: NSRunningApplication, on screen: DockScreen) {
        let plan = ScreenHider.plan(for: application.processIdentifier, on: screen)

        switch plan.action {
        case .minimize:
            // A click on an app in the background brings it forward; folding
            // away is what a click on the app you are already in means.
            guard application.isActive else {
                bringForward(application, bundleIdentifier: application.bundleIdentifier)
                return
            }
            let count = ScreenHider.apply(plan)
            Log.workspace.info("Folded \(count, privacy: .public) window(s) away on this screen")
        case .restore:
            let count = ScreenHider.apply(plan)
            bringForward(application, bundleIdentifier: application.bundleIdentifier)
            Log.workspace.info("Brought \(count, privacy: .public) window(s) back on this screen")
        case .nothing:
            bringForward(application, bundleIdentifier: application.bundleIdentifier)
        }
    }

    /// A hidden app stays hidden through a plain activation, so unhide first;
    /// then open it the way the system Dock does, which sends a reopen as well
    /// as activating. A running app with no windows makes a new one on reopen
    /// (Safari, Finder, Mail); merely activated, it would come to the front
    /// with nothing to show.
    private static func bringForward(_ application: NSRunningApplication, bundleIdentifier: String?) {
        if application.isHidden {
            application.unhide()
        }
        let installed = bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        open(at: application.bundleURL ?? installed)
    }

    private static func launch(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            // Which apps a user pins is their business, so identifiers are
            // redacted in the unified log rather than published to anyone who
            // can read it.
            Log.workspace.error("No application installed for \(bundleIdentifier, privacy: .private)")
            return
        }
        open(at: url)
    }

    private static func open(at url: URL?) {
        guard let url else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        Task {
            do {
                try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
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
