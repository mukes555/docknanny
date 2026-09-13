import SwiftUI
import UniformTypeIdentifiers

/// Manages the pinned set: what appears in every dock whether or not it is
/// running, and in what order.
///
/// Still a List underneath, because List is what gives drag-to-reorder on
/// macOS for free. Everything List draws of its own accord is switched off so
/// the rows sit in the same glass group as every other pane.
struct AppsSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEmpty {
                emptyState
            } else {
                pinnedGroup
                Spacer(minLength: 0)
                footer
            }
        }
    }

    private var isEmpty: Bool {
        store.settings.pinnedBundleIdentifiers.isEmpty
    }

    private var pinnedGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pinned")
                .settingsText(Theme.Text.section, Theme.Ink.primary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)

            List {
                ForEach(store.settings.pinnedBundleIdentifiers, id: \.self) { identifier in
                    PinnedAppRow(identifier: identifier) { remove(identifier) }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Theme.Line.hairline)
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Metric.rowPadding,
                                                  bottom: 0, trailing: Theme.Metric.rowPadding))
                }
                .onMove { source, destination in
                    store.settings.pinnedBundleIdentifiers.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(store.settings.pinnedBundleIdentifiers.count) * PinnedAppRow.height + 8)
            .raisedSurface()
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 22)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
/// than a gesture: macOS List has no swipe-to-delete, so the earlier hint
/// promising one described something that could not happen.
private struct PinnedAppRow: View {
    static let height: CGFloat = 52

    let identifier: String
    let onRemove: () -> Void

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
