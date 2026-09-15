import SwiftUI

struct BehaviorSettingsView: View {
    @Bindable var store: SettingsStore

    /// Mirrors the login-item service. Reading `SMAppService` is a synchronous
    /// cross-process call, far too expensive to sit in a binding's getter where
    /// SwiftUI would run it on every body evaluation.
    @State private var launchesAtLogin = false
    @State private var loginItemOutcome = LaunchAtLogin.Outcome.applied
    @State private var accessibilityTrusted = Accessibility.isTrusted

    /// Flips every dock, the ones with an auto-hide value of their own
    /// included, the same as the shortcut does.
    private var autoHideEverywhere: Binding<Bool> {
        Binding(
            get: { store.settings.autoHide },
            set: { store.settings.setAutoHideEverywhere($0) }
        )
    }

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
                    isOn: autoHideEverywhere
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

            windowsGroup

            SettingsGroup(title: "Startup") {
                SettingsToggle(
                    title: "Launch at login",
                    subtitle: launchAtLoginSubtitle,
                    isOn: launchAtLoginBinding
                )
            }
        }
        .onAppear { launchesAtLogin = LaunchAtLogin.isEnabled }
        .task { await watchAccessibility() }
    }

    /// The grant lands in System Settings behind this window; checking back
    /// each second while the pane is open lets the row update without a
    /// relaunch when macOS applies it live.
    private func watchAccessibility() async {
        while !Task.isCancelled {
            accessibilityTrusted = Accessibility.isTrusted
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private var windowsGroup: some View {
        SettingsGroup(title: "Windows") {
            SettingsToggle(
                title: "Keep windows clear of the dock",
                subtitle: "A window opened or zoomed into a dock's space is nudged to sit beside it, "
                    + "the way windows stop beside the system Dock. Dragging one under the dock still works.",
                isOn: $store.settings.keepWindowsClear
            )
            if store.settings.keepWindowsClear, !accessibilityTrusted {
                SettingsDivider()
                SettingRow(
                    title: "Needs Accessibility",
                    subtitle: "Nudging another app's window means reading and setting its frame, "
                        + "which is what Accessibility access is for."
                ) {
                    Button("Grant...") { Accessibility.request() }
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
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

    private var launchAtLoginSubtitle: String {
        switch loginItemOutcome {
        case .applied: "Start DockNanny automatically when you sign in."
        case .requiresApproval: "Waiting for your approval under General > Login Items in System Settings."
        case .refused: "macOS refused the change. An unsigned build cannot register a login item."
        }
    }

    /// The service, not the stored value, is the source of truth: the user can
    /// change the registration in System Settings behind the app's back. An
    /// item parked for approval opens the pane where approval is given.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchesAtLogin },
            set: { requested in
                loginItemOutcome = LaunchAtLogin.set(requested)
                launchesAtLogin = LaunchAtLogin.isEnabled
                store.settings.launchAtLogin = launchesAtLogin
                if loginItemOutcome == .requiresApproval {
                    LaunchAtLogin.openLoginItems()
                }
            }
        )
    }
}
