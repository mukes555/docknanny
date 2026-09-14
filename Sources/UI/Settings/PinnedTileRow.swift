import SwiftUI

/// One entry of a pin list: an app, a spacer, or a folder or document.
///
/// Removal is a visible button that appears on hover rather than a gesture:
/// macOS List has no swipe-to-delete. Rows in a mirrored list pass nil and
/// get no button, because the place to edit them is the system Dock.
struct PinnedTileRow: View {
    static let height: CGFloat = 52

    let entry: String
    let onRemove: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            icon.frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).settingsText(Theme.Text.row, Theme.Ink.primary)
                Text(subtitle).settingsText(Theme.Text.caption, Theme.Ink.tertiary)
            }

            Spacer()

            if isMissing {
                Text(fileURL == nil ? "Not installed" : "Missing")
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
                .accessibilityLabel("Remove \(title) from Dock")
            }
        }
        .frame(height: Self.height)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
    }

    private var isSpacer: Bool { entry == DockItem.spacerIdentifier }

    private var fileURL: URL? {
        guard let url = URL(string: entry), url.isFileURL else { return nil }
        return url
    }

    private var title: String {
        if isSpacer { return "Spacer" }
        if let fileURL { return FileManager.default.displayName(atPath: fileURL.path) }
        return DockContents.displayName(forBundleIdentifier: entry)
    }

    private var subtitle: String {
        if isSpacer { return "An empty tile" }
        if let fileURL { return fileURL.path(percentEncoded: false) }
        return entry
    }

    private var isMissing: Bool {
        if isSpacer { return false }
        if let fileURL { return !FileManager.default.fileExists(atPath: fileURL.path) }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry) == nil
    }

    @ViewBuilder
    private var icon: some View {
        if isSpacer {
            Image(systemName: "rectangle.dashed").foregroundStyle(Theme.Ink.secondary)
        } else if let fileURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: fileURL.path)).resizable().scaledToFit()
        } else if let image = DockContents.icon(forBundleIdentifier: entry) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "questionmark.app.dashed").foregroundStyle(Theme.Ink.secondary)
        }
    }
}
