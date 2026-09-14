import AppKit

/// Everything a dock's tiles are built from, gathered by the coordinator.
struct DockSource {
    /// Bundle identifiers, with ``DockItem/spacerIdentifier`` for gaps.
    var pinned: [String] = []
    var running: [RunningApp] = []
    /// The system Dock's Recent Applications, or nil when that section is
    /// off. With it on, unpinned running apps join this section rather than
    /// the apps section, which is where the system Dock puts them.
    var recents: [String]?
    /// File URLs as strings, plus spacers, for the section after the apps.
    var others: [String] = []
    var showsTrash = false
    var isTrashFull = false
}

/// Turns a ``DockSource`` into the list a single dock shows.
///
/// Pinned apps come first and keep their configured order, so tiles never
/// move under the pointer just because something launched. Running apps
/// follow, then folders and the Trash. This is the system Dock's contract,
/// including the detail that unpinned running apps sit in the apps section
/// with no divider unless Recent Applications is on.
enum DockContents {
    static func items(
        source: DockSource,
        configuration: ResolvedDockConfiguration,
        iconProvider: @escaping (DockItem.Kind) -> NSImage?,
        nameProvider: @escaping (String) -> String = DockContents.displayName(forBundleIdentifier:)
    ) -> [DockItem] {
        var builder = Builder(
            source: source, configuration: configuration, iconProvider: iconProvider, nameProvider: nameProvider
        )
        builder.addPinnedApps()
        if configuration.showRunningApps {
            builder.addRunningApps()
        }
        builder.addOthers()
        if source.showsTrash {
            builder.add(.trash(isFull: source.isTrashFull), section: .others)
        }
        return builder.items
    }

    /// Accumulates tiles while enforcing unique ids. A bundle id may appear
    /// more than once on both sides: an app can run several processes, and a
    /// hand-edited settings file can repeat a pin. Two tiles sharing an id
    /// give ForEach duplicate identity, which corrupts SwiftUI's diffing
    /// rather than merely looking wrong.
    private struct Builder {
        let source: DockSource
        let configuration: ResolvedDockConfiguration
        let iconProvider: (DockItem.Kind) -> NSImage?
        let nameProvider: (String) -> String

        private(set) var items: [DockItem] = []
        private var emitted = Set<String>()
        private var runningByIdentifier: [String: RunningApp]

        init(
            source: DockSource,
            configuration: ResolvedDockConfiguration,
            iconProvider: @escaping (DockItem.Kind) -> NSImage?,
            nameProvider: @escaping (String) -> String
        ) {
            self.source = source
            self.configuration = configuration
            self.iconProvider = iconProvider
            self.nameProvider = nameProvider
            runningByIdentifier = Dictionary(
                source.running.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }

        mutating func addPinnedApps() {
            var spacers = 0
            for entry in source.pinned {
                if entry == DockItem.spacerIdentifier {
                    add(.spacer(ordinal: spacers), section: .apps)
                    spacers += 1
                } else {
                    addApp(entry, isPinned: true, section: .apps)
                }
            }
        }

        mutating func addRunningApps() {
            for identifier in source.recents ?? [] {
                addApp(identifier, isPinned: false, section: .recents)
            }
            let section: DockItem.Section = source.recents == nil ? .apps : .recents
            for app in source.running {
                addApp(app.id, isPinned: false, section: section)
            }
        }

        mutating func addOthers() {
            var spacers = 0
            for entry in source.others {
                if entry == DockItem.spacerIdentifier {
                    add(.spacer(ordinal: spacers), section: .others)
                    spacers += 1
                } else if let url = URL(string: entry), url.isFileURL {
                    add(.file(url), section: .others)
                }
            }
        }

        private mutating func addApp(_ identifier: String, isPinned: Bool, section: DockItem.Section) {
            guard configuration.allows(bundleIdentifier: identifier), emitted.insert(identifier).inserted else {
                return
            }
            let running = runningByIdentifier[identifier]
            items.append(DockItem(
                id: identifier,
                kind: .app(bundleIdentifier: identifier),
                section: section,
                name: running?.localizedName ?? nameProvider(identifier),
                icon: running?.icon ?? iconProvider(.app(bundleIdentifier: identifier)),
                isRunning: running != nil,
                isPinned: isPinned,
                isActive: running?.isActive ?? false
            ))
        }

        /// The fixtures: spacers, files and the Trash are pinned by nature.
        mutating func add(_ kind: DockItem.Kind, section: DockItem.Section) {
            let id = identifier(for: kind, section: section)
            guard emitted.insert(id).inserted else { return }
            items.append(DockItem(
                id: id,
                kind: kind,
                section: section,
                name: name(for: kind),
                icon: iconProvider(kind),
                isRunning: false,
                isPinned: true,
                isActive: false
            ))
        }

        private func identifier(for kind: DockItem.Kind, section: DockItem.Section) -> String {
            switch kind {
            case .app(let identifier): identifier
            case .file(let url): url.absoluteString
            case .trash: "trash"
            case .spacer(let ordinal): "\(DockItem.spacerIdentifier):\(section):\(ordinal)"
            }
        }

        private func name(for kind: DockItem.Kind) -> String {
            switch kind {
            case .app(let identifier): nameProvider(identifier)
            case .file(let url): FileManager.default.displayName(atPath: url.path)
            case .trash: "Trash"
            case .spacer: ""
            }
        }
    }

    // MARK: Names and icons

    /// The name a person knows the app by.
    ///
    /// Prefers the bundle's own display name, then its bundle name, then the
    /// filename without its extension. FileManager.displayName was used before
    /// and returned "Finder.app" whenever Finder is set to show all extensions.
    /// Falls back to the last path component of the bundle id, which reads far
    /// better than an empty label when an app is pinned but not installed.
    static func displayName(forBundleIdentifier bundleIdentifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return bundleIdentifier.components(separatedBy: ".").last ?? bundleIdentifier
        }
        let info = Bundle(url: url)?.localizedInfoDictionary ?? Bundle(url: url)?.infoDictionary
        let declared = (info?["CFBundleDisplayName"] ?? info?["CFBundleName"]) as? String
        return declared ?? url.deletingPathExtension().lastPathComponent
    }

    static func icon(for kind: DockItem.Kind) -> NSImage? {
        switch kind {
        case .app(let identifier):
            return icon(forBundleIdentifier: identifier)
        case .file(let url):
            return NSWorkspace.shared.icon(forFile: url.path)
        case .trash(let isFull):
            // The Trash folder's own file icon is a plain folder. These two
            // named images are the ones the system Dock draws.
            return NSImage(named: isFull ? NSImage.trashFullName : NSImage.trashEmptyName)
        case .spacer:
            return nil
        }
    }

    static func icon(forBundleIdentifier identifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
