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
    private var settingsWindow: SettingsWindowController?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit-test bundle is hosted by this very app, so without this guard
        // every test run opens real panels, plants a status item and can throw
        // the onboarding window in front of whoever is at the keyboard. The
        // suite covers pure logic and needs none of it.
        guard !Self.isRunningUnitTests else { return }

        // Accessory policy keeps macdock out of the system Dock and the
        // command-tab switcher, which is the right shape for something that
        // lives permanently on screen.
        NSApp.setActivationPolicy(.accessory)
        MainMenu.install()

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
            onOpenSettings: { [weak self] in self?.showSettings() },
            onOpenSetup: { [weak self] in self?.showOnboarding() },
            onQuit: { NSApp.terminate(nil) }
        )

        Log.app.info("macdock launched on \(displays.displays.count, privacy: .public) display(s)")

        guard !openWindowRequestedOnCommandLine() else { return }

        // The dock is usable without Accessibility (launching and focusing apps
        // needs no permission), so the wizard informs rather than blocks.
        guard !permissions.isSatisfied else { return }
        showOnboarding()
    }

    /// `macdock --settings` and `macdock --setup` open a window directly.
    /// Handy when walking someone through a problem, and the only way to reach
    /// these windows without the menu bar.
    private func openWindowRequestedOnCommandLine() -> Bool {
        let arguments = Set(CommandLine.arguments)

        if arguments.contains("--settings") {
            showSettings()
            return true
        }
        if arguments.contains("--setup") {
            showOnboarding()
            return true
        }
        return false
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    @objc
    func openSettingsFromMenu() {
        showSettings()
    }

    private func showSettings() {
        guard let settings, let displays else { return }
        let controller = settingsWindow ?? SettingsWindowController(store: settings, displays: displays)
        settingsWindow = controller
        controller.show()
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
