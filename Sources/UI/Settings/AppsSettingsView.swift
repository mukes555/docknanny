import SwiftUI
import UniformTypeIdentifiers

/// What the docks pin, and where that list comes from.
///
/// By default it is the system Dock's own lists, in the system Dock's order,
/// so every display shows the same dock. Turning that off gives custom lists
/// with drag-to-reorder; any edit made to a mirrored dock does the same fork
/// automatically rather than landing in a list nothing reads.
struct AppsSettingsView: View {
    @Bindable var store: SettingsStore

    @State private var mirrored = SystemDockMonitor.Snapshot()

    private var isMirroring: Bool { store.settings.mirrorSystemDock }
    private var pins: [String] { store.settings.pinnedBundleIdentifiers }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPane {
                sourceGroup
                if isMirroring {
                    mirroredGroup
                    if !mirrored.others.isEmpty {
                        readOnlyList(title: "Folders, from the system Dock", entries: mirrored.others)
                    }
                } else if pins.isEmpty {
                    emptyState
                } else {
                    customGroup
                    if !store.settings.pinnedOthers.isEmpty {
                        othersGroup
                    }
                }
            }
            if !isMirroring, !pins.isEmpty {
                footer
            }
        }
        .task { mirrored = SystemDockMonitor.read() }
        .onChange(of: isMirroring) { _, _ in mirrored = SystemDockMonitor.read() }
    }

    // MARK: Source

    private var sourceGroup: some View {
        SettingsGroup(title: "Source") {
            SettingsToggle(
                title: "Mirror the system Dock",
                subtitle: "Use the apps, folders and spacers in your Mac's Dock, in the same order. "
                    + "Rearrange the Dock and every display follows.",
                isOn: $store.settings.mirrorSystemDock
            )
            SettingsDivider()
            SettingsToggle(
                title: "Show the Trash",
                subtitle: "At the end of every dock. Drop files on it to delete them.",
                isOn: $store.settings.showTrash
            )
            // The Dock's slider runs past this app's range; the row offers the
            // nearest size this app can take, or it could never be satisfied.
            if let systemTileSize = mirrored.tileSize.map({ $0.clamped(to: Settings.Limits.iconSize) }),
               systemTileSize != store.settings.iconSize {
                SettingsDivider()
                SettingRow(
                    title: "Match the Dock's icon size",
                    subtitle: "Your Dock uses \(systemTileSize.wholeNumberLabel) pt; "
                        + "DockNanny is at \(store.settings.iconSize.wholeNumberLabel) pt."
                ) {
                    Button("Use \(systemTileSize.wholeNumberLabel) pt") {
                        store.settings.iconSize = systemTileSize
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
            if mirrored.pins.isEmpty {
                SettingRow(
                    title: "Nothing pinned in the system Dock",
                    subtitle: "Running apps still appear. Turn mirroring off to pin apps here instead."
                ) { EmptyView() }
            } else {
                rows(mirrored.pins)
            }
            SettingsDivider()
            SettingRow(
                title: "Rearrange these in your Mac's Dock",
                subtitle: "Editing here, or dragging tiles in a dock, switches to a custom list seeded from this one."
            ) { EmptyView() }
        }
    }

    private func readOnlyList(title: String, entries: [String]) -> some View {
        SettingsGroup(title: title) { rows(entries) }
    }

    /// Spacers repeat, so the row identity is the position, not the entry.
    private func rows(_ entries: [String]) -> some View {
        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
            if index > 0 { SettingsDivider() }
            PinnedTileRow(entry: entry, onRemove: nil)
                .padding(.horizontal, Theme.Metric.rowPadding)
        }
    }

    // MARK: Custom

    private var customGroup: some View {
        SettingsGroup(title: "Pinned") {
            editableList($store.settings.pinnedBundleIdentifiers)
        }
    }

    private var othersGroup: some View {
        SettingsGroup(title: "Folders and files") {
            editableList($store.settings.pinnedOthers)
        }
    }

    private func editableList(_ entries: Binding<[String]>) -> some View {
        List {
            ForEach(Array(entries.wrappedValue.enumerated()), id: \.offset) { index, entry in
                PinnedTileRow(entry: entry) { entries.wrappedValue.remove(at: index) }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.Line.hairline)
                    .listRowInsets(EdgeInsets(
                        top: 0, leading: Theme.Metric.rowPadding, bottom: 0, trailing: Theme.Metric.rowPadding
                    ))
            }
            .onMove { source, destination in
                entries.wrappedValue.move(fromOffsets: source, toOffset: destination)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(height: CGFloat(entries.wrappedValue.count) * PinnedTileRow.height + 8)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { addApplications() } label: { Label("Add Apps...", systemImage: "plus") }
            Button { store.settings.pinnedBundleIdentifiers.append(DockItem.spacerIdentifier) } label: {
                Label("Add Spacer", systemImage: "rectangle.dashed")
            }
            Spacer()
            Text("Drag a row to reorder. Drop an app or folder onto any dock to pin it.")
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

    private func addApplications() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(filePath: "/Applications")

        guard panel.runModal() == .OK else { return }

        let identifiers = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        for identifier in identifiers where !pins.contains(identifier) {
            store.settings.pinnedBundleIdentifiers.append(identifier)
        }
    }
}
