import AppKit
import Foundation

/// What the system Dock is showing, read from its preferences.
///
/// macdock's premise is a dock on every display: the same dock, not a second
/// one with its own idea of what is pinned. The Dock writes its layout to the
/// com.apple.dock domain through cfprefsd whenever it changes, so reading that
/// domain is enough to follow rearrangements, with no private API and no
/// permission. Polling is deliberate: the Dock replaces its plist wholesale,
/// which defeats a file watcher, and a two-second read of a few preferences is
/// free. The Trash's state rides along because it is polled on the same clock.
@MainActor
@Observable
final class SystemDockMonitor {
    struct Snapshot: Equatable, Sendable {
        var pins: [String] = []
        var others: [String] = []
        /// nil when "Show recent applications in Dock" is off.
        var recents: [String]?
        var tileSize: Double?
        /// nil when magnification is off.
        var magnifiedTileSize: Double?
        var autoHides = false
        var edge: DockEdge?
        var isTrashFull = false
    }

    private(set) var snapshot = Snapshot()

    var pins: [String] { snapshot.pins }
    var others: [String] { snapshot.others }
    var recents: [String]? { snapshot.recents }
    var tileSize: Double? { snapshot.tileSize }
    var isTrashFull: Bool { snapshot.isTrashFull }

    private let poll = TaskBox()

    init() {
        refresh()
        poll.task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    func refresh() {
        let latest = Self.read()
        guard latest != snapshot else { return }
        snapshot = latest
    }

    /// A String, not a CFString: only Sendable statics may be nonisolated
    /// under Swift 6, and the reader runs off the main actor.
    nonisolated private static let domain = "com.apple.dock"

    nonisolated static func read() -> Snapshot {
        CFPreferencesAppSynchronize(domain as CFString)

        // The Dock's own default for recents is on; the key only exists once
        // someone has touched the checkbox.
        let showsRecents = (value("show-recents") as? NSNumber)?.boolValue ?? true
        let magnifies = (value("magnification") as? NSNumber)?.boolValue ?? false

        return Snapshot(
            pins: SystemDockTiles.pins(fromPersistentApps: tiles("persistent-apps")),
            others: SystemDockTiles.others(fromPersistentOthers: tiles("persistent-others")),
            recents: showsRecents ? SystemDockTiles.bundleIdentifiers(fromRecentApps: tiles("recent-apps")) : nil,
            tileSize: (value("tilesize") as? NSNumber)?.doubleValue,
            magnifiedTileSize: magnifies ? (value("largesize") as? NSNumber)?.doubleValue : nil,
            autoHides: (value("autohide") as? NSNumber)?.boolValue ?? false,
            edge: DockEdge(dockOrientation: value("orientation") as? String),
            isTrashFull: Trash.isFull()
        )
    }

    nonisolated private static func tiles(_ key: String) -> [[String: Any]] {
        value(key) as? [[String: Any]] ?? []
    }

    nonisolated private static func value(_ key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }
}
