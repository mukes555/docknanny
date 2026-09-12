import SwiftUI

struct AppearanceSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        SettingsPane {
            SettingsGroup(title: "Tiles") {
                SettingsSlider(title: "Icon size", value: $store.settings.iconSize, range: 24...96)
                Divider()
                SettingsSlider(title: "Spacing", value: $store.settings.itemSpacing, range: 0...24)
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
                    range: 1.0...2.5,
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
                    range: 0.2...1,
                    step: 0.05,
                    format: { "\(Int($0 * 100))%" }
                )
                Divider()
                SettingsSlider(
                    title: "Corner radius",
                    value: $store.settings.cornerRadiusScale,
                    range: 0...0.5,
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
