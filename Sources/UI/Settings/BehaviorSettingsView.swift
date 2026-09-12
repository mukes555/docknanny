import SwiftUI

struct BehaviorSettingsView: View {
    @Bindable var store: SettingsStore

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
                    subtitle: "Reveal the dock by moving the pointer to the screen edge.",
                    isOn: $store.settings.autoHide
                )
                Divider()
                SettingsSlider(
                    title: "Reveal delay",
                    value: $store.settings.autoHideDelay,
                    range: 0...1.5,
                    step: 0.05,
                    format: { String(format: "%.2fs", $0) }
                )
                Divider()
                SettingsToggle(
                    title: "Hide during full screen",
                    subtitle: "Keep the dock out of the way of full-screen apps.",
                    isOn: $store.settings.hideDuringFullscreen
                )
            }

            SettingsGroup(title: "Clicking") {
                SettingsPicker(
                    title: "When the app is already active",
                    selection: $store.settings.activeClickBehavior
                )
            }

            SettingsGroup(title: "Startup") {
                SettingsToggle(
                    title: "Launch at login",
                    subtitle: "Start macdock automatically when you sign in.",
                    isOn: launchAtLoginBinding
                )
            }
        }
    }

    /// Bound to the login item service rather than to the stored value, because
    /// the user can change the registration in System Settings behind our back.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { enabled in
                LaunchAtLogin.set(enabled)
                store.settings.launchAtLogin = enabled
            }
        )
    }
}
