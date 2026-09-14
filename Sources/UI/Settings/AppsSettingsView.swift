import SwiftUI
import UniformTypeIdentifiers

/// What the docks pin, and where that list comes from.
///
/// By default it is the system Dock's own list, in the system Dock's order,
/// so every display shows the same dock. Turning that off gives a custom list
/// with drag-to-reorder; any edit made to a mirrored dock does the same fork
/// automatically rather than landing in a list nothing reads.
struct AppsSettingsView: View {
    @Bindable var store: SettingsStore

    @State private var mirrored: [String] = []
    @State private var systemTileSize: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPane {
                sourceGroup
                if store.settings.mirrorSystemDock {
                    mirroredGroup
                } else if store.settings.pinnedBundleIdentifiers.isEmpty {
                    emptyState
                } else {
                    customGroup
                }
            }
            if !store.settings.mirrorSystemDock, !store.settings.pinnedBundleIdentifiers.isEmpty {
                footer
            }
        }
        .task { readSystemDock() }
        .onChange(of: store.settings.mirrorSystemDock) { _, _ in readSystemDock() }
    }

    private func readSystemDock() {
        mirrored = SystemDockMonitor.readPinned()
        systemTileSize = SystemDockMonitor.readTileSize()
    }

    // MARK: Source

    private var sourceGroup: some View {
        SettingsGroup(title: "Source") {
            SettingsToggle(
                title: "Mirror the system Dock",
                subtitle: "Use the apps pinned in your Mac's Dock, in the same order. "
                    + "Rearrange the Dock and every display follows.",
                isOn: $store.settings.mirrorSystemDock
            )
            if let systemTileSize, systemTileSize != store.settings.iconSize {
                SettingsDivider()
                SettingRow(
                    title: "Match the Dock's icon size",
                    subtitle: "Your Dock uses \(Int(systemTileSize)) pt; "
                        + "macdock is at \(Int(store.settings.iconSize)) pt."
                ) {
                    Button("Use \(Int(systemTileSize)) pt") {
                        store.settings.iconSize = systemTileSize.clamped(to: Settings.Limits.iconSize)
                    }
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    // MARK: Mirrored

    private var mirroredGroup: some View {
        SettingsGroup(title: "Pinned, from the system Dock") {
            if mirrored.isEmpty {
                SettingRow(
                    title: "Nothing pinned in the system Dock",
                    subtitle: "Running apps still appear. Turn mirroring off to pin apps here instead."
                ) { EmptyView() }
            } else {
                ForEach(Array(mirrored.enumerated()), id: \.element) { index, identifier in
                    if index > 0 { SettingsDivider() }
                    PinnedAppRow(identifier: identifier, onRemove: nil)
                        .padding(.horizontal, Theme.Metric.rowPadding)
                }
            }
            SettingsDivider()
            SettingRow(
                title: "Rearrange these in your Mac's Dock",
                subtitle: "Editing here, or dragging tiles in a dock, switches to a custom list seeded from this one."
            ) { EmptyView() }
        }
    }

    // MARK: Custom

    private var customGroup: some View {
        SettingsGroup(title: "Pinned") {
            List {
                ForEach(store.settings.pinnedBundleIdentifiers, id: \.self) { identifier in
                    PinnedAppRow(identifier: identifier) { remove(identifier) }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Theme.Line.hairline)
                        .listRowInsets(EdgeInsets(
                            top: 0, leading: Theme.Metric.rowPadding, bottom: 0, trailing: Theme.Metric.rowPadding
                        ))
                }
                .onMove { source, destination in
                    store.settings.pinnedBundleIdentifiers.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(store.settings.pinnedBundleIdentifiers.count) * PinnedAppRow.height + 8)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { addApplications() } label: { Label("Add Apps...", systemImage: "plus") }
                .controlSize(.regular)
            Spacer()
            Text("Drag a row to reorder. Drop an app onto any dock to pin it.")
                .settingsText(Theme.Text.caption, Theme.Ink.secondary)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 22)
    }

    /// The empty state carries its own call to action, so no footer.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No pinned apps", systemImage: "square.grid.2x2")
        } description: {
            Text("Running apps still appear in the dock. Pin the ones you want within reach even when they are closed.")
        } actions: {
            Button("Add Apps...") { addApplications() }
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func remove(_ identifier: String) {
        store.settings.pinnedBundleIdentifiers.removeAll { $0 == identifier }
    }

    private func addApplications() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(filePath: "/Applications")

        guard panel.runModal() == .OK else { return }

        let identifiers = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        for identifier in identifiers where !store.settings.pinnedBundleIdentifiers.contains(identifier) {
            store.settings.pinnedBundleIdentifiers.append(identifier)
        }
    }
}

/// One pinned app. Removal is a visible button that appears on hover rather
/// than a gesture: macOS List has no swipe-to-delete. Rows in a mirrored list
/// pass nil and get no button, because the place to edit them is the Dock.
private struct PinnedAppRow: View {
    static let height: CGFloat = 52

    let identifier: String
    let onRemove: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            icon.frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(DockContents.displayName(forBundleIdentifier: identifier))
                    .settingsText(Theme.Text.row, Theme.Ink.primary)
                Text(identifier)
                    .settingsText(Theme.Text.caption, Theme.Ink.tertiary)
            }

            Spacer()

            if !isInstalled {
                Text("Not installed")
                    .settingsText(Theme.Text.caption, Theme.Status.warning)
            }

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Ink.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
                .help("Remove from Dock")
                .accessibilityLabel("Remove \(DockContents.displayName(forBundleIdentifier: identifier)) from Dock")
            }
        }
        .frame(height: Self.height)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var icon: some View {
        if let image = DockContents.icon(forBundleIdentifier: identifier) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "questionmark.app.dashed").foregroundStyle(Theme.Ink.secondary)
        }
    }

    private var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) != nil
    }
}
