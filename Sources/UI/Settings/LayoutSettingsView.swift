import SwiftUI

struct LayoutSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        SettingsPane {
            DockPreview(settings: store.settings)

            SettingsGroup(title: "Placement") {
                SettingsPicker(
                    title: "Edge",
                    subtitle: "Which side of each display the dock hugs.",
                    selection: $store.settings.edge
                )
                SettingsDivider()
                SettingsPicker(
                    title: "Alignment",
                    subtitle: "Where along that edge it sits.",
                    selection: $store.settings.alignment
                )
                SettingsDivider()
                SettingsSlider(
                    title: "Margin",
                    subtitle: "Gap between the dock and the screen edge.",
                    value: $store.settings.margin,
                    range: Settings.Limits.margin
                )
            }

            SettingsGroup(title: "Displays") {
                SettingsToggle(
                    title: "Show on the primary display",
                    subtitle: "Turn this off if you keep the system Dock there.",
                    isOn: $store.settings.showOnPrimaryDisplay
                )
            }
        }
    }
}
