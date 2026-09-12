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
        guard running.activate() else {
            Log.workspace.notice("Activation refused for \(bundleIdentifier, privacy: .public)")
            return
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
            Log.workspace.error("No application installed for \(bundleIdentifier, privacy: .public)")
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
