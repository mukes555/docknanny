import AppKit

/// Keeps one dock panel per eligible display in step with the world.
///
/// Everything upstream is `@Observable`, so rather than wiring a notification
/// per source this watches all three and re-synchronises whenever any of them
/// changes. Panels are keyed by display id, so a screen that disappears takes
/// its panel with it and a reconnected one gets its settings back.
@MainActor
final class DockCoordinator {
    private let displays: DisplayRegistry
    private let apps: RunningAppsMonitor
    private let settings: SettingsStore

    private var controllers: [CGDirectDisplayID: DockPanelController] = [:]

    init(displays: DisplayRegistry, apps: RunningAppsMonitor, settings: SettingsStore) {
        self.displays = displays
        self.apps = apps
        self.settings = settings

        synchronise()
        observe()
    }

    func closeAll() {
        for controller in controllers.values {
            controller.close()
        }
        controllers.removeAll()
    }

    /// `withObservationTracking` fires once per change, so the observation is
    /// re-armed after each synchronise. The hop through a task matters: the
    /// callback runs *before* the new value is readable.
    private func observe() {
        withObservationTracking {
            _ = displays.displays
            _ = apps.apps
            _ = settings.settings
        } onChange: {
            Task { @MainActor in
                self.synchronise()
                self.observe()
            }
        }
    }

    private func synchronise() {
        var surviving: Set<CGDirectDisplayID> = []

        for display in displays.displays {
            let configuration = settings.settings.resolved(for: display)
            guard configuration.isEnabled else { continue }

            surviving.insert(display.id)
            let items = buildItems(for: configuration)

            if let existing = controllers[display.id] {
                existing.update(display: display, configuration: configuration, items: items)
            } else {
                controllers[display.id] = DockPanelController(
                    display: display,
                    configuration: configuration,
                    items: items
                )
            }
        }

        closeControllers(notIn: surviving)
    }

    private func buildItems(for configuration: ResolvedDockConfiguration) -> [DockItem] {
        DockContents.items(
            pinned: settings.settings.pinnedBundleIdentifiers,
            running: apps.apps,
            configuration: configuration,
            iconProvider: DockContents.icon(forBundleIdentifier:)
        )
    }

    private func closeControllers(notIn surviving: Set<CGDirectDisplayID>) {
        let departed = controllers.keys.filter { !surviving.contains($0) }
        for identifier in departed {
            controllers[identifier]?.close()
            controllers[identifier] = nil
        }
    }
}
