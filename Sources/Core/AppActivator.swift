import AppKit

/// Launches, focuses or hides the application behind a dock tile.
@MainActor
enum AppActivator {
    static func activate(bundleIdentifier: String, whenActive behavior: ActiveClickBehavior) {
        guard let running = runningApplication(withBundleIdentifier: bundleIdentifier) else {
            launch(bundleIdentifier: bundleIdentifier)
            return
        }

        if running.isActive {
            applyActiveBehavior(behavior, to: running)
            return
        }

        // A hidden app stays hidden through a plain activation, so unhide
        // first; then open it the way the system Dock does, which sends a
        // reopen as well as activating. A running app with no windows makes
        // a new one on reopen (Safari, Finder, Mail); merely activated, it
        // would come to the front with nothing to show.
        if running.isHidden {
            running.unhide()
        }
        open(at: running.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier))
    }

    private static func applyActiveBehavior(
        _ behavior: ActiveClickBehavior,
        to application: NSRunningApplication
    ) {
        switch behavior {
        case .doNothing:
            return
        case .hide:
            application.hide()
        }
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
