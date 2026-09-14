import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsStore?
    private var displays: DisplayRegistry?
    private var apps: RunningAppsMonitor?
    private var coordinator: DockCoordinator?
    private var hotkeys: HotkeyController?
    private var statusItem: StatusItemController?
    private var onboarding: OnboardingWindowController?
    private var settingsWindow: SettingsWindowController?
    private var tray: TrayPanelController?

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
        let coordinator = DockCoordinator(
            displays: displays,
            apps: apps,
            settings: settings,
            openSetup: { [weak self] in self?.showOnboarding() }
        )
        self.coordinator = coordinator
        self.hotkeys = HotkeyController(settings: settings, coordinator: coordinator)
        self.tray = TrayPanelController(
            store: settings,
            displays: displays,
            onOpenSettings: { [weak self] section in self?.showSettings(section: section) },
            onQuit: { NSApp.terminate(nil) }
        )
        self.statusItem = StatusItemController(
            onShowTray: { [weak self] button in self?.tray?.toggle(relativeTo: button) },
            onOpenSettings: { [weak self] in self?.showSettings() },
            onOpenSetup: { [weak self] in self?.showOnboarding() },
            onQuit: { NSApp.terminate(nil) }
        )

        Log.app.info("macdock launched on \(displays.displays.count, privacy: .public) display(s)")

        guard !openWindowRequestedOnCommandLine() else { return }

        // Shown once, and only to say that nothing needs granting.
        guard !settings.settings.hasSeenWelcome else { return }
        settings.settings.hasSeenWelcome = true
        showOnboarding()
    }

    /// `macdock --settings` and `macdock --setup` open a window directly.
    /// Handy when walking someone through a problem, and the only way to reach
    /// these windows without the menu bar.
    private func openWindowRequestedOnCommandLine() -> Bool {
        let arguments = Set(CommandLine.arguments)

        if arguments.contains("--settings") {
            showSettings(section: Self.requestedSection(in: CommandLine.arguments))
            return true
        }
        if arguments.contains("--setup") {
            showOnboarding()
            return true
        }
        if arguments.contains("--tray") {
            // The status item is created above but is not in the menu bar's
            // window until the run loop turns, and a popover will not anchor to
            // a view with no window. One turn later it is there.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(1500))
                guard let self, let button = statusItem?.button else { return }
                tray?.toggle(relativeTo: button)
            }
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

    /// `macdock --settings --section=apps` opens straight to one pane, which
    /// beats talking someone through a sidebar over a bug report.
    private static func requestedSection(in arguments: [String]) -> SettingsSection {
        let prefix = "--section="
        guard let raw = arguments.first(where: { $0.hasPrefix(prefix) })?.dropFirst(prefix.count),
              let section = SettingsSection(rawValue: String(raw)) else {
            return .layout
        }
        return section
    }

    private func showSettings(section: SettingsSection = .layout) {
        guard let settings, let displays else { return }
        let controller = settingsWindow
            ?? SettingsWindowController(store: settings, displays: displays, section: section)
        settingsWindow = controller
        controller.show()
    }

    private func showOnboarding() {
        let controller = onboarding ?? OnboardingWindowController(
            onOpenSettings: { [weak self] in self?.showSettings() }
        )
        onboarding = controller
        controller.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.closeAll()
        settings?.flush()
    }

    /// Reopening a running menu-bar app, from Spotlight, Finder or `open -a`,
    /// is the one gesture that has nothing else to mean, so it opens Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
