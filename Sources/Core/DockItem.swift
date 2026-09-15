import AppKit

/// One tile in a dock.
struct DockItem: Identifiable, Equatable {
    /// What the tile stands for. Everything except an app is a fixture of
    /// the system Dock that a faithful mirror has to show as well.
    enum Kind: Equatable {
        case app(bundleIdentifier: String)
        /// A folder or document in the section after the apps.
        case file(URL)
        case trash(isFull: Bool)
        /// An empty, tile-sized gap. The ordinal says which spacer in its
        /// section's pin list this is, so removing one removes the right one.
        case spacer(ordinal: Int)
    }

    /// Which run of tiles this belongs to. The dock draws a hairline wherever
    /// the section changes between neighbours, as the system Dock does.
    enum Section: Equatable {
        case apps, recents, others
    }

    let id: String
    let kind: Kind
    let section: Section
    let name: String
    let icon: NSImage?
    let isRunning: Bool
    let isPinned: Bool
    let isActive: Bool

    /// The pin-list entry that stands for a spacer. Not a bundle identifier,
    /// so it can never collide with an app.
    static let spacerIdentifier = "DockNanny.spacer"

    var bundleIdentifier: String? {
        if case .app(let identifier) = kind { return identifier }
        return nil
    }

    var fileURL: URL? {
        if case .file(let url) = kind { return url }
        return nil
    }

    /// Pixels are not compared: an NSImage has no useful equality, and
    /// reloading the same icon is not a change worth a re-render. Whether
    /// there is an icon at all is: an app pinned before it was installed
    /// gets its icon the moment the placeholder can be replaced.
    static func == (lhs: DockItem, rhs: DockItem) -> Bool {
        lhs.id == rhs.id
            && lhs.kind == rhs.kind
            && lhs.section == rhs.section
            && lhs.name == rhs.name
            && (lhs.icon == nil) == (rhs.icon == nil)
            && lhs.isRunning == rhs.isRunning
            && lhs.isPinned == rhs.isPinned
            && lhs.isActive == rhs.isActive
    }
}
