import SwiftUI

struct AppearanceSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        SettingsPane {
            DockPreview(settings: store.settings)

            SettingsGroup(title: "Tiles") {
                SettingsSlider(title: "Icon size", value: $store.settings.iconSize, range: Settings.Limits.iconSize)
                Divider()
                SettingsSlider(title: "Spacing", value: $store.settings.itemSpacing, range: Settings.Limits.itemSpacing)
                Divider()
                SettingsPicker(
                    title: "Running indicator",
                    selection: $store.settings.indicatorStyle
                )
            }

            SettingsGroup(title: "Magnification") {
                SettingsToggle(
                    title: "Magnify on hover",
                    subtitle: "Tiles swell as the pointer approaches, like the system Dock.",
                    isOn: $store.settings.isMagnificationEnabled
                )
                Divider()
                SettingsSlider(
                    title: store.settings.isMagnificationEnabled ? "Magnified size" : "Hover size",
                    value: magnitudeBinding,
                    range: Settings.Limits.scale,
                    step: 0.05,
                    format: { String(format: "%.2fx", $0) }
                )
            }

            SettingsGroup(title: "Background") {
                SettingsPicker(title: "Style", selection: $store.settings.chromeStyle)
                Divider()
                SettingsSlider(
                    title: "Opacity",
                    value: $store.settings.chromeOpacity,
                    range: Settings.Limits.chromeOpacity,
                    step: 0.05,
                    format: { "\(Int($0 * 100))%" }
                )
                Divider()
                SettingsSlider(
                    title: "Corner radius",
                    value: $store.settings.cornerRadiusScale,
                    range: Settings.Limits.cornerRadiusScale,
                    step: 0.02,
                    format: { String(format: "%.2f", $0) }
                )
            }
        }
    }

    /// One slider drives whichever scale is actually in play, so the control
    /// never sits there adjusting something the user cannot see.
    private var magnitudeBinding: Binding<Double> {
        store.settings.isMagnificationEnabled
            ? $store.settings.magnificationScale
            : $store.settings.hoverScale
    }
}
