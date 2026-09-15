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

    enum Outcome {
        case applied
        /// Registered, but macOS holds the item until the person approves it
        /// in Login Items; it does this after they once disabled it there.
        case requiresApproval
        case refused
    }

    /// What became of the change. macOS can refuse registration (an unsigned
    /// build), or accept it and wait for approval, and a toggle that snaps
    /// back with no explanation is worse than one that says why. `register`
    /// does not throw for the waiting case, so the status is asked afterwards.
    @discardableResult
    static func set(_ enabled: Bool) -> Outcome {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
            return .refused
        }
        return enabled && SMAppService.mainApp.status == .requiresApproval ? .requiresApproval : .applied
    }

    static func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
