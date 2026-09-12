import SwiftUI

struct DisplaysSettingsView: View {
    @Bindable var store: SettingsStore
    let displays: DisplayRegistry

    var body: some View {
        SettingsPane {
            if displays.displays.isEmpty {
                ContentUnavailableView(
                    "No displays detected",
                    systemImage: "display.trianglebadge.exclamationmark"
                )
            } else {
                ForEach(displays.displays) { display in
                    DisplayOverrideCard(
                        display: display,
                        globalSettings: store.settings,
                        override: binding(for: display)
                    )
                }
            }
        }
    }

    private func binding(for display: Display) -> Binding<DisplayOverride> {
        Binding(
            get: { store.settings.override(forDisplay: display.id) },
            set: { store.settings.setOverride($0, forDisplay: display.id) }
        )
    }
}
