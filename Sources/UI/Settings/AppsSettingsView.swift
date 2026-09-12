import SwiftUI
import UniformTypeIdentifiers

/// Manages the pinned set: what appears in every dock whether or not it is
/// running, and in what order.
struct AppsSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            list
            Divider()
            toolbar
        }
    }

    private var list: some View {
        List {
            ForEach(store.settings.pinnedBundleIdentifiers, id: \.self) { identifier in
                row(for: identifier)
            }
            .onMove { source, destination in
                store.settings.pinnedBundleIdentifiers.move(fromOffsets: source, toOffset: destination)
            }
            .onDelete { offsets in
                store.settings.pinnedBundleIdentifiers.remove(atOffsets: offsets)
            }
        }
        .listStyle(.inset)
    }

    private func row(for identifier: String) -> some View {
        HStack(spacing: 10) {
            icon(for: identifier)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(name(for: identifier))
                    .font(.system(size: 12))
                Text(identifier)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !isInstalled(identifier) {
                Text("Not installed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func icon(for identifier: String) -> some View {
        if let image = DockContents.icon(forBundleIdentifier: identifier) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "questionmark.app.dashed")
                .foregroundStyle(.secondary)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                addApplications()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .controlSize(.small)

            Spacer()

            Text("Drag to reorder. Swipe left on a row to remove it.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
        .padding(12)
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

    private func isInstalled(_ identifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) != nil
    }

    private func name(for identifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return identifier.components(separatedBy: ".").last ?? identifier
        }
        return FileManager.default.displayName(atPath: url.path)
    }
}
