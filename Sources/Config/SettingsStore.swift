import Foundation

/// Loads, holds and persists ``Settings``.
///
/// Writes are coalesced: dragging a size slider produces one file write when
/// the user stops, not one per frame.
@MainActor
@Observable
final class SettingsStore {
    var settings: Settings {
        didSet {
            BrandPalette.current = settings.brandPalette
            guard settings != oldValue else { return }
            scheduleSave()
        }
    }

    let fileURL: URL
    private let writeDelay: Duration
    private var saveTask: Task<Void, Never>?

    /// A settings file is a few kilobytes; anything much larger is not one,
    /// and is refused before it is read into memory.
    static let importSizeLimit = 1_000_000

    enum ImportError: Error {
        case tooLarge
    }

    init(directory: URL? = nil, writeDelay: Duration = .seconds(1)) {
        let folder = directory ?? Self.defaultDirectory
        // Resolved, so a settings.json kept as a symlink (into a dotfiles
        // folder, say) is written through rather than replaced by the atomic
        // save with a plain file.
        self.fileURL = folder.appending(path: "settings.json").resolvingSymlinksInPath()
        self.writeDelay = writeDelay
        self.settings = Self.load(from: fileURL)
        BrandPalette.current = settings.brandPalette
    }

    /// Forces a pending write to disk immediately. Called on termination, when
    /// there is no later chance to flush.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        write(settings)
    }

    /// The same file that is saved, written wherever asked, so a backup and
    /// the live file are interchangeable.
    func export(to url: URL) throws {
        try Self.encode(settings).write(to: url, options: .atomic)
    }

    /// Reads with the same tolerance as launch: unknown keys are ignored and
    /// missing ones take defaults, so a file from an older or newer DockNanny
    /// still imports. What was seen on first run stays seen.
    func importSettings(from url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= Self.importSizeLimit else { throw ImportError.tooLarge }
        var imported = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: url))
        imported.hasSeenWelcome = settings.hasSeenWelcome
        settings = imported
    }

    func resetToDefaults() {
        var defaults = Settings()
        defaults.hasSeenWelcome = settings.hasSeenWelcome
        settings = defaults
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self, writeDelay, settings] in
            try? await Task.sleep(for: writeDelay)
            guard !Task.isCancelled else { return }
            self?.write(settings)
        }
    }

    private func write(_ settings: Settings) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Self.encode(settings).write(to: fileURL, options: .atomic)
        } catch {
            Log.settings.error("Could not save settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func encode(_ settings: Settings) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }

    /// A settings file that cannot be read is replaced by defaults rather than
    /// blocking launch. Losing preferences is recoverable; a dock that will not
    /// start is not. The unreadable file is kept beside the new one, since a
    /// hand edit with one stray comma is the usual cause and easily repaired.
    /// A file that exists but will not even open (permissions, a directory in
    /// its place) is moved aside for the same reason: left where it is, the
    /// first save would write defaults over it.
    private static func load(from url: URL) -> Settings {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            guard FileManager.default.fileExists(atPath: url.path) else { return Settings() }
            let reason = error.localizedDescription
            Log.settings.error("Settings file cannot be opened, set aside: \(reason, privacy: .private)")
            let keepsake = url.appendingPathExtension("unreadable")
            try? FileManager.default.removeItem(at: keepsake)
            try? FileManager.default.moveItem(at: url, to: keepsake)
            return Settings()
        }
        do {
            return try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            let reason = error.localizedDescription
            Log.settings.error("Settings unreadable, using defaults: \(reason, privacy: .public)")
            let keepsake = url.appendingPathExtension("unreadable")
            try? FileManager.default.removeItem(at: keepsake)
            try? FileManager.default.copyItem(at: url, to: keepsake)
            return Settings()
        }
    }

    private static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let root = base.first ?? URL.temporaryDirectory
        let directory = root.appending(path: "DockNanny")
        migrateSettingsFromOldName(into: directory, from: root.appending(path: "macdock"))
        return directory
    }

    /// The app shipped its first builds as "macdock". A settings file from
    /// then is copied across once, so the rename costs nobody their setup.
    private static func migrateSettingsFromOldName(into directory: URL, from old: URL) {
        let manager = FileManager.default
        let target = directory.appending(path: "settings.json")
        let source = old.appending(path: "settings.json")
        guard !manager.fileExists(atPath: target.path), manager.fileExists(atPath: source.path) else { return }
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            // Copied under another name and renamed into place, so a crash
            // mid-copy cannot leave a half file that reads as corrupt and is
            // never retried.
            let staging = directory.appending(path: "settings.json.migrating")
            try? manager.removeItem(at: staging)
            try manager.copyItem(at: source, to: staging)
            try manager.moveItem(at: staging, to: target)
            Log.settings.info("Settings carried over from the macdock folder")
        } catch {
            let reason = error.localizedDescription
            Log.settings.error("Could not carry settings over: \(reason, privacy: .public)")
        }
    }
}
