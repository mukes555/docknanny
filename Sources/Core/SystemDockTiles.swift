import Foundation

/// Reads the system Dock's tile dictionaries.
///
/// The Dock stores each tile as a `tile-data` dictionary with a `tile-type`
/// beside it. Apps carry a bundle identifier (older entries only a file URL),
/// folders and documents carry a file URL, spacers carry nothing. Anything
/// unreadable is skipped rather than failing the whole list.
enum SystemDockTiles {
    /// A small spacer is half a tile wide in the system Dock. Slots here are
    /// uniform, so it becomes a full one: a gap in the right place rather than
    /// no gap at all.
    private static let spacerTypes: Set<String> = ["spacer-tile", "small-spacer-tile", "flex-spacer-tile"]

    /// Pin-list entries for the apps section: bundle identifiers, with the
    /// spacer sentinel wherever the Dock has a gap.
    static func pins(fromPersistentApps entries: [[String: Any]]) -> [String] {
        var seen = Set<String>()
        return entries.compactMap { entry -> String? in
            if isSpacer(entry) { return DockItem.spacerIdentifier }
            guard let identifier = bundleIdentifier(from: entry), seen.insert(identifier).inserted else {
                return nil
            }
            return identifier
        }
    }

    /// Entries for the section after the apps: file URLs as strings, with the
    /// spacer sentinel for gaps. Recent-items stacks and web links have no
    /// DockNanny equivalent yet and are left out.
    static func others(fromPersistentOthers entries: [[String: Any]]) -> [String] {
        var seen = Set<String>()
        return entries.compactMap { entry -> String? in
            if isSpacer(entry) { return DockItem.spacerIdentifier }
            guard let url = fileURL(from: entry), seen.insert(url.absoluteString).inserted else { return nil }
            return url.absoluteString
        }
    }

    static func bundleIdentifiers(fromRecentApps entries: [[String: Any]]) -> [String] {
        pins(fromPersistentApps: entries).filter { $0 != DockItem.spacerIdentifier }
    }

    private static func isSpacer(_ entry: [String: Any]) -> Bool {
        guard let type = entry["tile-type"] as? String else { return false }
        return spacerTypes.contains(type)
    }

    private static func bundleIdentifier(from entry: [String: Any]) -> String? {
        guard let tile = entry["tile-data"] as? [String: Any] else { return nil }
        if let identifier = tile["bundle-identifier"] as? String, !identifier.isEmpty {
            return identifier
        }
        guard let url = fileURL(from: entry) else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    /// `_CFURLStringType` 0 means the string is a plain path; 15 a URL.
    private static func fileURL(from entry: [String: Any]) -> URL? {
        guard let tile = entry["tile-data"] as? [String: Any],
              let file = tile["file-data"] as? [String: Any],
              let string = file["_CFURLString"] as? String, !string.isEmpty else {
            return nil
        }
        let isPlainPath = (file["_CFURLStringType"] as? Int ?? 15) == 0
        if isPlainPath {
            return URL(fileURLWithPath: string)
        }
        guard let url = URL(string: string), url.isFileURL else { return nil }
        return url
    }
}
