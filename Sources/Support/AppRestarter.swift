import AppKit

/// Relaunches macdock.
///
/// Accessibility permission is bound to a running process, so a grant made
/// while the app is open does not take effect until it starts again. Rather
/// than explaining that, the onboarding window offers a button.
@MainActor
enum AppRestarter {
    static func restart() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        let bundleURL = Bundle.main.bundleURL

        Task {
            do {
                try await NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
                NSApp.terminate(nil)
            } catch {
                Log.app.error("Restart failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
