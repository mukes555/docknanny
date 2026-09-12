import AppKit

/// Launches or focuses the application behind a dock tile.
///
/// Phase 1 deliberately stops at launch and activate. Window cycling,
/// minimise and move-to-this-display arrive with `WindowIndex` in Phase 3,
/// once window identity is resolved properly rather than guessed from titles.
@MainActor
enum AppActivator {
    static func activate(bundleIdentifier: String) {
        if let running = runningApplication(withBundleIdentifier: bundleIdentifier) {
            let didActivate = running.activate()
            guard !didActivate else { return }
            Log.workspace.notice("Activation refused for \(bundleIdentifier, privacy: .public)")
            return
        }
        launch(bundleIdentifier: bundleIdentifier)
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
