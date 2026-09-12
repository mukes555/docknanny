import SwiftUI

struct AppearanceSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        SettingsPane {
            DockPreview(settings: store.settings)

            SettingsGroup(title: "Tiles") {
                SettingsSlider(title: "Icon size", value: $store.settings.iconSize, range: Settings.Limits.iconSize)
                SettingsDivider()
                SettingsSlider(title: "Spacing", value: $store.settings.itemSpacing, range: Settings.Limits.itemSpacing)
                SettingsDivider()
                SettingsPicker(title: "Running indicator", selection: $store.settings.indicatorStyle)
            }

            SettingsGroup(title: "Magnification") {
                SettingsToggle(
                    title: "Magnify on hover",
                    subtitle: "Neighbouring tiles swell too, like the system Dock.",
                    isOn: $store.settings.isMagnificationEnabled
                )
                SettingsDivider()
                SettingsSlider(
                    title: store.settings.isMagnificationEnabled ? "Magnified size" : "Hover size",
                    value: $store.settings.magnificationScale,
                    range: Settings.Limits.scale,
                    step: 0.05,
                    format: { String(format: "%.2fx", $0) }
                )
            }

            SettingsGroup(title: "Background") {
                SettingsPicker(title: "Style", selection: $store.settings.chromeStyle)
                SettingsDivider()
                TintRow(
                    title: "Tint",
                    subtitle: "Give each screen its own colour and you can tell them apart at a glance.",
                    selection: $store.settings.tint
                )
            }
        }
    }
}

/// The tint swatches.
///
/// Swatches rather than a menu because colour is the one setting you should be
/// able to choose by looking, and rather than a colour well because every entry
/// here is picked to sit under translucent chrome without muddying the icons.
struct TintRow: View {
    let title: String
    var subtitle: String?
    @Binding var selection: DockTint

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).settingsText(Theme.Text.row, Theme.Ink.primary)
                if let subtitle {
                    Text(subtitle)
                        .settingsText(Theme.Text.caption, Theme.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 7) {
                ForEach(DockTint.allCases) { tint in
                    Swatch(tint: tint, isSelected: tint == selection) { selection = tint }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.Metric.rowPadding)
        .padding(.vertical, 11)
    }
}

private struct Swatch: View {
    let tint: DockTint
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: 20, height: 20)
                    .overlay {
                        Circle().strokeBorder(Theme.Line.strong, lineWidth: 1)
                    }

                if tint == .none {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Ink.secondary)
                }
            }
            .padding(2.5)
            .overlay {
                if isSelected {
                    Circle().strokeBorder(Theme.accent, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .help(tint.localizedName)
        .accessibilityLabel(tint.localizedName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var fill: Color {
        tint.color ?? Theme.Surface.control
    }
}
