import SwiftUI
import UniformTypeIdentifiers

/// Starting points, and the file behind everything.
struct PresetsSettingsView: View {
    @Bindable var store: SettingsStore

    @State private var applied: SettingsPreset?
    @State private var confirmingReset = false
    @State private var importFailed = false

    var body: some View {
        SettingsPane {
            SettingsGroup(title: "Starting points") {
                ForEach(Array(SettingsPreset.allCases.enumerated()), id: \.element.id) { index, preset in
                    if index > 0 { SettingsDivider() }
                    presetRow(preset)
                }
            }

            SettingsGroup(title: "Settings file") {
                SettingRow(
                    title: "Export",
                    subtitle: "Save every setting to a file you can keep or move to another Mac."
                ) {
                    Button("Export...") { exportSettings() }
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                SettingsDivider()
                SettingRow(
                    title: "Import",
                    subtitle: importFailed
                        ? "That file could not be read as DockNanny settings."
                        : "Replace every setting with the contents of an exported file."
                ) {
                    Button("Import...") { importSettings() }
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                SettingsDivider()
                SettingRow(
                    title: "Reset",
                    subtitle: "Back to how DockNanny came, including pins and per-display settings."
                ) {
                    Button("Reset to Defaults...") { confirmingReset = true }
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .confirmationDialog(
            "Reset every setting?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset to Defaults", role: .destructive) { store.resetToDefaults() }
        } message: {
            Text("Pins, per-display settings and shortcuts all go back to their defaults. Export first to keep a copy.")
        }
    }

    private func presetRow(_ preset: SettingsPreset) -> some View {
        SettingRow(title: preset.title, subtitle: preset.summary) {
            HStack(spacing: 10) {
                if applied == preset {
                    Text("Applied")
                        .settingsText(Theme.Text.caption, Theme.Status.success)
                        .transition(.opacity)
                }
                Button("Apply") { apply(preset) }
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func apply(_ preset: SettingsPreset) {
        preset.apply(to: &store.settings, dock: SystemDockMonitor.read())
        withAnimation(.easeOut(duration: 0.15)) { applied = preset }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "DockNanny settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.export(to: url)
        } catch {
            Log.settings.error("Export failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.importSettings(from: url)
            importFailed = false
            applied = nil
        } catch {
            importFailed = true
            // The description names the file the person chose.
            Log.settings.error("Import failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}
