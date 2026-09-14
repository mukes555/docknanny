import AppKit

/// Keeps the global shortcuts in step with settings, and points them at the
/// coordinator.
@MainActor
final class HotkeyController {
    private let settings: SettingsStore
    private let coordinator: DockCoordinator
    private let center = HotkeyCenter()

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
            Task { @MainActor in
                self.apply()
                self.observe()
            }
        }
    }

    private func apply() {
        let current = settings.settings
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
