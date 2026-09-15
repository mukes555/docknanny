import AppKit

/// Names and icons for tiles, remembered.
///
/// Every observation change rebuilds every dock's items, and each item's name
/// and icon came from LaunchServices and a bundle read each time: a slider
/// drag rebuilt them hundreds of times a second. Folders and documents are
/// the same story with a stat and a Finder icon lookup, on a volume that may
/// be slow or gone. Entries expire, so an app installed or removed later, or
/// a folder renamed, is still noticed within a minute.
@MainActor
final class AppMetadataCache {
    private struct Entry {
        let name: String
        let icon: NSImage?
        let stamp: ContinuousClock.Instant
    }

    private var entries: [String: Entry] = [:]
    private static let lifetime = Duration.seconds(60)

    func name(for identifier: String) -> String {
        entry(for: .app(bundleIdentifier: identifier)).name
    }

    func name(forFile url: URL) -> String {
        entry(for: .file(url)).name
    }

    func icon(for kind: DockItem.Kind) -> NSImage? {
        switch kind {
        case .app, .file: entry(for: kind).icon
        case .trash, .spacer: DockContents.icon(for: kind)
        }
    }

    private func entry(for kind: DockItem.Kind) -> Entry {
        let key: String
        switch kind {
        case .app(let identifier): key = identifier
        case .file(let url): key = url.absoluteString
        case .trash, .spacer: key = ""
        }

        let now = ContinuousClock.now
        if let hit = entries[key], now - hit.stamp < Self.lifetime {
            return hit
        }
        let fresh = Entry(name: Self.name(for: kind), icon: DockContents.icon(for: kind), stamp: now)
        entries[key] = fresh
        return fresh
    }

    private static func name(for kind: DockItem.Kind) -> String {
        switch kind {
        case .app(let identifier): DockContents.displayName(forBundleIdentifier: identifier)
        case .file(let url): DockContents.displayName(forFile: url)
        case .trash, .spacer: ""
        }
    }
}
