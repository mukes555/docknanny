import SwiftUI

/// One display's deviations from the global settings.
struct DisplayOverrideCard: View {
    let display: Display
    let globalSettings: Settings
    @Binding var override: DisplayOverride

    var body: some View {
        SettingsGroup(title: cardTitle) {
            SettingsToggle(
                title: "Show a dock here",
                isOn: Binding(
                    get: { override.isEnabled ?? inheritedEnabled },
                    set: { override.isEnabled = $0 }
                )
            )
            SettingsDivider()
            SettingsOptionalPicker(
                title: "Edge",
                selection: $override.edge,
                inheritedName: globalSettings.edge.localizedName
            )
            SettingsDivider()
            SettingsOptionalPicker(
                title: "Alignment",
                selection: $override.alignment,
                inheritedName: globalSettings.alignment.localizedName
            )
            SettingsDivider()
            SettingsSlider(
                title: "Icon size",
                subtitle: override.iconSize == nil ? "Following the global size." : nil,
                value: Binding(
                    get: { override.iconSize ?? globalSettings.iconSize },
                    set: { override.iconSize = $0 }
                ),
                range: Settings.Limits.iconSize
            )
            SettingsDivider()
            appFilterRow
            SettingsDivider()
            resetRow
        }
    }

    /// Individual controls cannot express "inherit" once touched: a slider has
    /// no nil and a switch has no third state. Without this row an override was
    /// a one-way door, and a per-display "show a dock here" could silently
    /// contradict the global toggle forever.
    private var resetRow: some View {
        SettingRow(
            title: "Overrides",
            subtitle: override.isDefault
                ? "This display follows the global settings."
                : "This display has settings of its own."
        ) {
            Button("Reset to Global") { override = DisplayOverride() }
                .controlSize(.small)
                .disabled(override.isDefault)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var cardTitle: String {
        let dimensions = "\(Int(display.frame.width))x\(Int(display.frame.height))"
        let role = display.isPrimary ? " (primary)" : ""
        return "\(display.localizedName) - \(dimensions)\(role)"
    }

    private var inheritedEnabled: Bool {
        display.isPrimary ? globalSettings.showOnPrimaryDisplay : true
    }

    /// Per-display app filtering: the feature that lets one screen carry comms
    /// and another carry tools.
    private var appFilterRow: some View {
        SettingRow(
            title: "Apps shown",
            subtitle: override.allowedBundleIdentifiers == nil
                ? "Every app allowed by the global settings."
                : "\(override.allowedBundleIdentifiers?.count ?? 0) chosen."
        ) {
            HStack(spacing: 6) {
                Picker("", selection: filterModeBinding) {
                    Text("All apps").tag(false)
                    Text("Only chosen").tag(true)
                }
                .labelsHidden()
                .controlSize(.small)
            }
        }
    }

    /// Switching to "only chosen" seeds the list with everything currently
    /// pinned, so the dock never blanks out the moment the mode changes.
    private var filterModeBinding: Binding<Bool> {
        Binding(
            get: { override.allowedBundleIdentifiers != nil },
            set: { isFiltered in
                override.allowedBundleIdentifiers = isFiltered
                    ? globalSettings.pinnedBundleIdentifiers
                    : nil
            }
        )
    }
}
