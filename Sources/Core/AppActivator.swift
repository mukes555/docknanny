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

        // A hidden app stays hidden through activate(), so unhide first.
        if running.isHidden {
            running.unhide()
        }
        if !running.activate() {
            Log.workspace.notice("Activation refused for \(bundleIdentifier, privacy: .private)")
        }
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

    private static func runningApplication(withBundleIdentifier identifier: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == identifier }
    }
}
