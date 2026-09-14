import AppKit

/// Keeps the global shortcuts in step with settings, and points them at the
/// coordinator.
@MainActor
final class HotkeyController {
    private let settings: SettingsStore
    private let coordinator: DockCoordinator
    private let center = HotkeyCenter()

    /// What the current registrations were made from. Observation fires for
    /// any change to the settings value, a slider tick included, and
    /// re-registering ten hot keys for an icon-size change is churn that can
    /// also drop a press that lands in the gap.
    private struct Choice: Equatable {
        let tiles: Bool
        let hiding: Bool
        let modifiers: HotkeyModifiers
    }

    private var applied: Choice?

    init(settings: SettingsStore, coordinator: DockCoordinator) {
        self.settings = settings
        self.coordinator = coordinator
        apply()
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = settings.settings.tileHotkeysEnabled
            _ = settings.settings.hidingHotkeyEnabled
            _ = settings.settings.hotkeyModifiers
        } onChange: {
            Task { @MainActor [weak self] in
                self?.apply()
                self?.observe()
            }
        }
    }

    private func apply() {
        let current = settings.settings
        let choice = Choice(
            tiles: current.tileHotkeysEnabled, hiding: current.hidingHotkeyEnabled, modifiers: current.hotkeyModifiers
        )
        guard choice != applied else { return }
        applied = choice

        var bindings: [HotkeyCenter.Binding] = []

        if current.tileHotkeysEnabled {
            for number in HotkeyRole.tileNumbers {
                bindings.append(HotkeyCenter.Binding(
                    role: .tile(number: number),
                    modifiers: current.hotkeyModifiers,
                    action: { [weak self] in self?.coordinator.activateTile(number: number) }
                ))
            }
        }
        if current.hidingHotkeyEnabled {
            bindings.append(HotkeyCenter.Binding(
                role: .toggleHiding,
                modifiers: current.hotkeyModifiers,
                action: { [weak self] in self?.settings.settings.autoHide.toggle() }
            ))
        }
        center.replaceAll(with: bindings)
    }
}
