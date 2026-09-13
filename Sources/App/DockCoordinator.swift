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
    private let systemDock = SystemDockMonitor()

    /// Built once and shared by every panel. The closures read current state
    /// when they run rather than closing over a snapshot, so a panel created
    /// before a setting changed still behaves correctly afterwards.
    private lazy var actions = makeActions()

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
            _ = systemDock.pinnedBundleIdentifiers
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
            let configuration = effectiveSettings.resolved(for: display)
            guard configuration.isEnabled else { continue }

            surviving.insert(display.id)
            let items = buildItems(for: configuration)

            if let existing = controllers[display.id] {
                existing.update(display: display, configuration: configuration, items: items)
            } else {
                controllers[display.id] = DockPanelController(
                    display: display,
                    configuration: configuration,
                    items: items,
                    actions: actions
                )
            }
        }

        closeControllers(notIn: surviving)
    }

    /// The coordinator owns the settings store, so pinning lives here rather
    /// than in a view reaching for global state.
    private func makeActions() -> DockActions {
        DockActions(
            activate: { [weak self] item in
                guard let self else { return }
                AppActivator.activate(
                    bundleIdentifier: item.id,
                    whenActive: settings.settings.activeClickBehavior
                )
            },
            togglePin: { [weak self] item in self?.togglePin(item.id) },
            reveal: DockCommands.reveal,
            hide: DockCommands.hide,
            quit: DockCommands.quit,
            pin: { [weak self] identifiers in self?.pin(identifiers) },
            move: { [weak self] identifier, target in self?.move(identifier, onto: target) },
            hideOthers: DockCommands.hideOthers
        )
    }

    /// Global settings with the system Dock's list substituted in while
    /// mirroring. Settings stays a pure value type; the substitution lives here
    /// because this is the one place that knows both sources.
    private var effectiveSettings: Settings {
        var effective = settings.settings
        if effective.mirrorSystemDock {
            effective.pinnedBundleIdentifiers = systemDock.pinnedBundleIdentifiers
        }
        return effective
    }

    /// A local edit while mirroring would otherwise land in a list nothing
    /// reads. Editing forks: the mirrored list becomes the custom one, then the
    /// edit applies to it, and the Apps pane shows that the fork happened.
    private func forkFromMirrorIfNeeded() {
        guard settings.settings.mirrorSystemDock else { return }
        settings.settings.mirrorSystemDock = false
        settings.settings.pinnedBundleIdentifiers = systemDock.pinnedBundleIdentifiers
    }

    private func togglePin(_ identifier: String) {
        forkFromMirrorIfNeeded()
        var pinned = settings.settings.pinnedBundleIdentifiers
        if let index = pinned.firstIndex(of: identifier) {
            pinned.remove(at: index)
        } else {
            pinned.append(identifier)
        }
        settings.settings.pinnedBundleIdentifiers = pinned
    }

    private func pin(_ identifiers: [String]) {
        forkFromMirrorIfNeeded()
        var pinned = settings.settings.pinnedBundleIdentifiers
        for identifier in identifiers where !pinned.contains(identifier) {
            pinned.append(identifier)
        }
        guard pinned != settings.settings.pinnedBundleIdentifiers else { return }
        settings.settings.pinnedBundleIdentifiers = pinned
    }

    /// Dropping one tile on another puts it in that tile's place. A tile that
    /// was merely running becomes pinned by the act of being arranged, which is
    /// what the gesture already implies.
    private func move(_ identifier: String, onto target: String) {
        forkFromMirrorIfNeeded()
        var pinned = settings.settings.pinnedBundleIdentifiers
        pinned.removeAll { $0 == identifier }

        if let index = pinned.firstIndex(of: target) {
            pinned.insert(identifier, at: index)
        } else {
            pinned.append(identifier)
        }

        guard pinned != settings.settings.pinnedBundleIdentifiers else { return }
        settings.settings.pinnedBundleIdentifiers = pinned
    }

    private func buildItems(for configuration: ResolvedDockConfiguration) -> [DockItem] {
        DockContents.items(
            pinned: configuration.pinnedBundleIdentifiers,
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
