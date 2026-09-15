import SwiftUI

/// What drops from the menu bar mark.
struct TrayView: View {
    @Bindable var store: SettingsStore
    let displays: DisplayRegistry
    let onOpenSettings: (SettingsSection) -> Void
    let onOpenSetup: () -> Void
    let onClose: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            group("Displays") {
                ForEach(Array(displays.displays.enumerated()), id: \.element.id) { index, display in
                    if index > 0 { SettingsDivider() }
                    TrayDisplayRow(store: store, display: display) { onOpenSettings(.displays) }
                }
            }

            group("Quick settings") {
                quickToggle("Mirror the system Dock", $store.settings.mirrorSystemDock)
                SettingsDivider()
                quickToggle("Magnify on hover", $store.settings.isMagnificationEnabled)
                SettingsDivider()
                quickToggle("Hide automatically", $store.settings.autoHide)
            }

            actions
        }
        .padding(12)
        .frame(width: 344)
        .onExitCommand(perform: onClose)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: Brand.appIcon)
                .resizable()
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("DockNanny").settingsText(Theme.Text.title, Theme.Ink.primary)
                Text(status).settingsText(Theme.Text.caption, Theme.Ink.secondary)
            }
            Spacer()
            Text(Self.version).settingsText(Theme.Text.caption, Theme.Ink.tertiary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private var status: String {
        let shown = displays.displays.filter { store.settings.resolved(for: $0).isEnabled }.count
        let count = displays.displays.count
        let docks = "\(shown) dock\(shown == 1 ? "" : "s") on \(count) display\(count == 1 ? "" : "s")"
        return store.settings.mirrorSystemDock ? "\(docks) · mirroring your Dock" : docks
    }

    private static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "v\(short ?? "dev")"
    }

    // MARK: Groups

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .settingsText(.system(size: 10.5, weight: .semibold), Theme.Ink.secondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .raisedSurface(corner: 10)
        }
    }

    private func quickToggle(_ title: String, _ isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).settingsText(Theme.Text.row, Theme.Ink.primary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.accent)
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 0) {
            TrayAction(symbol: "gearshape", title: "Settings…", keycap: "⌘,") { onOpenSettings(.layout) }
            SettingsDivider()
            TrayAction(symbol: "checkmark.shield", title: "Set Up DockNanny…", keycap: nil, action: onOpenSetup)
            SettingsDivider()
            TrayAction(symbol: "doc.text.magnifyingglass", title: "Reveal settings file", keycap: nil) {
                NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
            }
            SettingsDivider()
            TrayAction(symbol: "arrow.clockwise", title: "Relaunch", keycap: nil) { AppRestarter.restart() }
            SettingsDivider()
            TrayAction(symbol: "power", title: "Quit DockNanny", keycap: "⌘Q", action: onQuit)
        }
        .raisedSurface(corner: 10)
        .background(settingsShortcut)
    }

    /// Command-comma works while the tray is open, as it does everywhere else.
    private var settingsShortcut: some View {
        Button("") { onOpenSettings(.layout) }
            .keyboardShortcut(",", modifiers: .command)
            .hidden()
    }
}

private struct TrayAction: View {
    let symbol: String
    let title: String
    let keycap: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Ink.secondary)
                    .frame(width: 16)
                Text(title).settingsText(Theme.Text.row, Theme.Ink.primary)
                Spacer()
                if let keycap { Keycap(text: keycap) }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isHovered ? Theme.Surface.sidebarHover : .clear)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
