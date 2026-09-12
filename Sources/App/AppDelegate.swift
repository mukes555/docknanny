import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsStore?
    private var displays: DisplayRegistry?
    private var apps: RunningAppsMonitor?
    private var coordinator: DockCoordinator?
    private var statusItem: StatusItemController?
    private var permissions: PermissionsService?
    private var onboarding: OnboardingWindowController?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory policy keeps macdock out of the system Dock and the
        // command-tab switcher, which is the right shape for something that
        // lives permanently on screen.
        NSApp.setActivationPolicy(.accessory)

        let settings = SettingsStore()
        let displays = DisplayRegistry()
        let apps = RunningAppsMonitor()

        self.settings = settings
        self.displays = displays
        self.apps = apps
        let permissions = PermissionsService()
        self.permissions = permissions

        self.coordinator = DockCoordinator(displays: displays, apps: apps, settings: settings)
        self.statusItem = StatusItemController(
            onOpenSetup: { [weak self] in self?.showOnboarding() },
            onQuit: { NSApp.terminate(nil) }
        )

        Log.app.info("macdock launched on \(displays.displays.count, privacy: .public) display(s)")

        // The dock is usable without Accessibility (launching and focusing apps
        // needs no permission), so the wizard informs rather than blocks.
        guard !permissions.isSatisfied else { return }
        showOnboarding()
    }

    private func showOnboarding() {
        guard let permissions else { return }
        let controller = onboarding ?? OnboardingWindowController(permissions: permissions)
        onboarding = controller
        controller.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.closeAll()
        settings?.flush()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
