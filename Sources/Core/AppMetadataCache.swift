import AppKit

/// Names and icons by bundle identifier, remembered.
///
/// Every observation change rebuilds every dock's items, and each item's name
/// and icon came from LaunchServices and a bundle read each time: a slider
/// drag rebuilt them hundreds of times a second. Entries expire, so an app
/// installed or removed later is still noticed within a minute.
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
        entry(for: identifier).name
    }

    func icon(for kind: DockItem.Kind) -> NSImage? {
        if case .app(let identifier) = kind {
            return entry(for: identifier).icon
        }
        return DockContents.icon(for: kind)
    }

    private func entry(for identifier: String) -> Entry {
        let now = ContinuousClock.now
        if let hit = entries[identifier], now - hit.stamp < Self.lifetime {
            return hit
        }
        let fresh = Entry(
            name: DockContents.displayName(forBundleIdentifier: identifier),
            icon: DockContents.icon(forBundleIdentifier: identifier),
            stamp: now
        )
        entries[identifier] = fresh
        return fresh
    }
}
