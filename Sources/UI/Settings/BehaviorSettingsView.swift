import SwiftUI

struct BehaviorSettingsView: View {
    @Bindable var store: SettingsStore

    /// Mirrors the login-item service. Reading `SMAppService` is a synchronous
    /// cross-process call, far too expensive to sit in a binding's getter where
    /// SwiftUI would run it on every body evaluation.
    @State private var launchesAtLogin = false
    @State private var loginItemRefused = false

    var body: some View {
        SettingsPane {
            SettingsGroup(title: "Contents") {
                SettingsToggle(
                    title: "Show running apps",
                    subtitle: "Include apps that are open but not pinned.",
                    isOn: $store.settings.showRunningApps
                )
            }

            SettingsGroup(title: "Hiding") {
                SettingsToggle(
                    title: "Hide automatically",
                    subtitle: "The dock retreats to a sliver at the screen edge until you point at it.",
                    isOn: $store.settings.autoHide
                )
                SettingsDivider()
                SettingsSlider(
                    title: "Reveal delay",
                    subtitle: "How long the pointer must rest at the edge.",
                    value: $store.settings.autoHideDelay,
                    range: Settings.Limits.revealDelay,
                    step: 0.05,
                    format: { String(format: "%.2fs", $0) }
                )
            }

            SettingsGroup(title: "Clicking") {
                SettingsSegmented(
                    title: "When the app is already active",
                    selection: $store.settings.activeClickBehavior
                )
            }

            keyboardGroup

            SettingsGroup(title: "Startup") {
                SettingsToggle(
                    title: "Launch at login",
                    subtitle: loginItemRefused
                        ? "macOS refused the change. An unsigned build cannot register a login item."
                        : "Start macdock automatically when you sign in.",
                    isOn: launchAtLoginBinding
                )
            }
        }
        .onAppear { launchesAtLogin = LaunchAtLogin.isEnabled }
    }

    private var modifiers: String { store.settings.hotkeyModifiers.localizedName }

    private var keyboardGroup: some View {
        SettingsGroup(title: "Keyboard") {
            SettingsSegmented(
                title: "Shortcut modifiers",
                subtitle: "Held with the key named below. No permission is needed for these.",
                selection: $store.settings.hotkeyModifiers
            )
            SettingsDivider()
            SettingsToggle(
                title: "Open apps by number",
                subtitle: "\(modifiers)1 opens the first app on the dock under the pointer, "
                    + "\(modifiers)2 the second, up to \(modifiers)9.",
                isOn: $store.settings.tileHotkeysEnabled
            )
            SettingsDivider()
            SettingsToggle(
                title: "Toggle hiding with \(modifiers)D",
                subtitle: "Turns \"Hide automatically\" on and off, the way Option-Command-D does for the system Dock.",
                isOn: $store.settings.hidingHotkeyEnabled
            )
        }
    }

    /// The service, not the stored value, is the source of truth: the user can
    /// change the registration in System Settings behind the app's back.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchesAtLogin },
            set: { requested in
                loginItemRefused = !LaunchAtLogin.set(requested)
                launchesAtLogin = LaunchAtLogin.isEnabled
                store.settings.launchAtLogin = launchesAtLogin
            }
        )
    }
}
