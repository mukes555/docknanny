import ServiceManagement

/// Registers DockNanny to start with the user's session.
///
/// `SMAppService` reflects the real system state, which the user can change in
/// System Settings behind the app's back, so the stored preference is treated
/// as an intent and the service is always the source of truth.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns whether the change actually took. macOS can refuse registration
    /// (an unsigned build, a user-disabled login item), and a toggle that snaps
    /// back with no explanation is worse than one that says why.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            Log.app.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
