import SwiftUI

struct LayoutSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        SettingsPane {
            DockPreview(settings: store.settings)

            SettingsGroup(title: "Placement") {
                EdgeCardPicker(
                    title: "Edge",
                    subtitle: "Which side of each display the dock hugs.",
                    selection: $store.settings.edge
                )
                SettingsDivider()
                SettingsSegmented(
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
                    title: "Stay off the display with the system Dock",
                    subtitle: "That screen has a dock already. "
                        + "If the Dock moves to another display, DockNanny follows.",
                    isOn: $store.settings.skipSystemDockDisplay
                )
            }
        }
    }
}
