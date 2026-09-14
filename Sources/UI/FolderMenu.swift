import AppKit

/// A folder tile's click: the system Dock's "list" view of its contents.
///
/// The top level is read when the menu is built, so its size is known before
/// it is placed. Subfolders become submenus that read their own contents only
/// when opened, so pointing at a deep tree never costs more than one level.
@MainActor
final class FolderMenu: NSMenu, NSMenuDelegate {
    /// A folder with thousands of entries would take seconds to build and
    /// scroll forever. Past this the Finder is the better tool, and the menu
    /// says so.
    private static let entryLimit = 250

    private let url: URL
    private var isPopulated = false

    init(url: URL, populateNow: Bool = true) {
        self.url = url
        super.init(title: FileManager.default.displayName(atPath: url.path))
        delegate = self
        if populateNow {
            populate()
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("FolderMenu is built in code, never from a nib")
    }

    /// A folder is browsable when it is a real directory rather than a
    /// package: a document that happens to be a bundle opens like a document.
    static func isBrowsable(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate()
    }

    private func populate() {
        guard !isPopulated else { return }
        isPopulated = true

        let entries = Self.contents(of: url)
        for entry in entries.prefix(Self.entryLimit) {
            addItem(item(for: entry))
        }
        if entries.isEmpty {
            let empty = NSMenuItem(title: "Empty", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            addItem(empty)
        }
        if entries.count > Self.entryLimit {
            let remaining = entries.count - Self.entryLimit
            let more = NSMenuItem(title: "\(remaining) more in Finder", action: nil, keyEquivalent: "")
            more.isEnabled = false
            addItem(more)
        }

        addItem(.separator())
        addItem(ClosureMenuItem(title: "Open in Finder") { [url] in NSWorkspace.shared.open(url) })
    }

    private func item(for entry: URL) -> NSMenuItem {
        let item = ClosureMenuItem(title: FileManager.default.displayName(atPath: entry.path)) {
            NSWorkspace.shared.open(entry)
        }
        item.image = Self.icon(for: entry)
        if Self.isBrowsable(entry) {
            item.submenu = FolderMenu(url: entry, populateNow: false)
        }
        return item
    }

    /// Finder's order: case-insensitive, numbers compared as numbers.
    private static func contents(of url: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        return entries.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    /// Copied before resizing: the workspace may hand back a shared instance.
    private static func icon(for url: URL) -> NSImage? {
        guard let icon = NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage else { return nil }
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}
