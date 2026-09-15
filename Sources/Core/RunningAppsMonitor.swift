import AppKit

/// A running application, as the dock presents it.
struct RunningApp: Identifiable {
    let id: String
    let processIdentifier: pid_t
    let localizedName: String
    let icon: NSImage?
    let isActive: Bool
}

extension RunningApp: Equatable {
    /// Icons are excluded deliberately: comparing `NSImage` on every workspace
    /// notification would rebuild the dock constantly for no visible change.
    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.id == rhs.id
            && lhs.processIdentifier == rhs.processIdentifier
            && lhs.isActive == rhs.isActive
    }
}

/// Publishes the set of user-facing running applications.
@MainActor
@Observable
final class RunningAppsMonitor {
    private(set) var apps: [RunningApp] = []

    private let observers = ObserverTokens(center: NSWorkspace.shared.notificationCenter)
    private let ownBundleIdentifier = Bundle.main.bundleIdentifier

    init() {
        rebuild()
        observeWorkspace()
    }

    func isRunning(bundleIdentifier: String) -> Bool {
        apps.contains { $0.id == bundleIdentifier }
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        ]

        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.rebuild()
                }
            }
            observers.add(token)
        }
    }

    private func rebuild() {
        let rebuilt = NSWorkspace.shared.runningApplications
            .filter(isPresentable)
            .compactMap(Self.describe)

        guard rebuilt != apps else { return }
        apps = rebuilt
    }

    /// Only apps a user would recognise belong in a dock: agents, daemons and
    /// DockNanny itself are all excluded.
    private func isPresentable(_ application: NSRunningApplication) -> Bool {
        guard application.activationPolicy == .regular, !application.isTerminated else {
            return false
        }
        guard let identifier = application.bundleIdentifier else { return false }
        // LaunchServices can go on listing an app whose process the kernel
        // no longer has, for minutes. Seen in the field: the keeper asked it
        // for an observer several times a second the whole time. Signal 0
        // asks the kernel without sending anything.
        let processExists = kill(application.processIdentifier, 0) == 0 || errno == EPERM
        return identifier != ownBundleIdentifier && processExists
    }

    private static func describe(_ application: NSRunningApplication) -> RunningApp? {
        guard let identifier = application.bundleIdentifier else { return nil }
        return RunningApp(
            id: identifier,
            processIdentifier: application.processIdentifier,
            localizedName: application.localizedName ?? identifier,
            icon: application.icon,
            isActive: application.isActive
        )
    }
}
