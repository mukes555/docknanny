import AppKit

/// One tile in a dock.
struct DockItem: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: NSImage?
    let isRunning: Bool
    let isPinned: Bool
    let isActive: Bool

    static func == (lhs: DockItem, rhs: DockItem) -> Bool {
        lhs.id == rhs.id
            && lhs.isRunning == rhs.isRunning
            && lhs.isPinned == rhs.isPinned
            && lhs.isActive == rhs.isActive
    }
}

/// Merges pinned apps with running ones into the list a single dock shows.
///
/// Pinned apps come first and keep their configured order, so tiles never move
/// under the pointer just because something launched. Unpinned running apps
/// follow, which is the same contract as the system Dock.
enum DockContents {
    static func items(
        pinned: [String],
        running: [RunningApp],
        configuration: ResolvedDockConfiguration,
        iconProvider: (String) -> NSImage?
    ) -> [DockItem] {
        let runningByIdentifier = Dictionary(
            running.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // A bundle id may appear more than once on both sides: an app can run
        // several processes (helpers, a relaunch mid-quit), and a hand-edited
        // settings file can repeat a pin. Two tiles sharing an id give ForEach
        // duplicate identity, which corrupts SwiftUI's diffing rather than
        // merely looking wrong.
        let pinnedItems = uniqued(pinned)
            .filter(configuration.allows)
            .map { identifier in
                makeItem(
                    identifier: identifier,
                    running: runningByIdentifier[identifier],
                    isPinned: true,
                    iconProvider: iconProvider
                )
            }

        guard configuration.showRunningApps else { return pinnedItems }

        let pinnedSet = Set(pinned)
        var emitted = pinnedSet
        var extras: [DockItem] = []

        for app in running where !pinnedSet.contains(app.id) && configuration.allows(bundleIdentifier: app.id) {
            guard emitted.insert(app.id).inserted else { continue }
            extras.append(makeItem(identifier: app.id, running: app, isPinned: false, iconProvider: iconProvider))
        }

        return pinnedItems + extras
    }

    /// Order-preserving deduplication.
    private static func uniqued(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        return identifiers.filter { seen.insert($0).inserted }
    }

    private static func makeItem(
        identifier: String,
        running: RunningApp?,
        isPinned: Bool,
        iconProvider: (String) -> NSImage?
    ) -> DockItem {
        DockItem(
            id: identifier,
            name: running?.localizedName ?? Self.displayName(for: identifier),
            icon: running?.icon ?? iconProvider(identifier),
            isRunning: running != nil,
            isPinned: isPinned,
            isActive: running?.isActive ?? false
        )
    }

    /// Falls back to the last path component of the bundle id, which reads far
    /// better than an empty tooltip when an app is pinned but not installed.
    private static func displayName(for bundleIdentifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return bundleIdentifier.components(separatedBy: ".").last ?? bundleIdentifier
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    static func icon(forBundleIdentifier identifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
