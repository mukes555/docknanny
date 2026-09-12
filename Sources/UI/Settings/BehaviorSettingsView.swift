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

            SettingsGroup(title: "Clicking") {
                SettingsPicker(
                    title: "When the app is already active",
                    selection: $store.settings.activeClickBehavior
                )
            }

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
