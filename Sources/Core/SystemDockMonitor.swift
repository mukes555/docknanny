import AppKit
import Foundation

/// What the system Dock is showing, read from its preferences.
///
/// macdock's premise is a dock on every display: the same dock, not a second
/// one with its own idea of what is pinned. The Dock writes its layout to the
/// com.apple.dock domain through cfprefsd whenever it changes, so reading that
/// domain is enough to follow rearrangements, with no private API and no
/// permission. Polling is deliberate: the Dock replaces its plist wholesale,
/// which defeats a file watcher, and a two-second read of one preference is
/// free.
@MainActor
@Observable
final class SystemDockMonitor {
    private(set) var pinnedBundleIdentifiers: [String] = []
    private(set) var tileSize: Double?

    private var pollTask: Task<Void, Never>?

    init() {
        refresh()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    func refresh() {
        let latestPins = Self.readPinned()
        if latestPins != pinnedBundleIdentifiers {
            pinnedBundleIdentifiers = latestPins
        }
        let latestSize = Self.readTileSize()
        if latestSize != tileSize {
            tileSize = latestSize
        }
    }

    /// A String, not a CFString: only Sendable statics may be nonisolated
    /// under Swift 6, and the readers run off the main actor.
    nonisolated private static let domain = "com.apple.dock"

    nonisolated static func readPinned() -> [String] {
        CFPreferencesAppSynchronize(domain as CFString)
        let value = CFPreferencesCopyAppValue("persistent-apps" as CFString, domain as CFString)
        guard let raw = value as? [[String: Any]] else { return [] }
        return bundleIdentifiers(fromPersistentApps: raw)
    }

    nonisolated static func readTileSize() -> Double? {
        CFPreferencesAppSynchronize(domain as CFString)
        return (CFPreferencesCopyAppValue("tilesize" as CFString, domain as CFString) as? NSNumber)?.doubleValue
    }

    /// The Dock stores each pinned app as a tile-data dictionary. Modern
    /// entries carry the bundle identifier directly; older ones carry only a
    /// file URL, which is resolved through the bundle on disk. Anything
    /// unreadable is skipped rather than failing the whole list.
    nonisolated static func bundleIdentifiers(fromPersistentApps entries: [[String: Any]]) -> [String] {
        var seen = Set<String>()
        return entries
            .compactMap { entry -> String? in
                guard let tile = entry["tile-data"] as? [String: Any] else { return nil }
                if let identifier = tile["bundle-identifier"] as? String, !identifier.isEmpty {
                    return identifier
                }
                guard let file = tile["file-data"] as? [String: Any],
                      let urlString = file["_CFURLString"] as? String,
                      let url = URL(string: urlString) else { return nil }
                return Bundle(url: url)?.bundleIdentifier
            }
            .filter { seen.insert($0).inserted }
    }
}
