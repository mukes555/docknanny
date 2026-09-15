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
            guard settings != oldValue else { return }
            scheduleSave()
        }
    }

    let fileURL: URL
    private let writeDelay: Duration
    private var saveTask: Task<Void, Never>?

    init(directory: URL? = nil, writeDelay: Duration = .seconds(1)) {
        let folder = directory ?? Self.defaultDirectory
        self.fileURL = folder.appending(path: "settings.json")
        self.writeDelay = writeDelay
        self.settings = Self.load(from: fileURL)
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
    private static func load(from url: URL) -> Settings {
        guard let data = try? Data(contentsOf: url) else { return Settings() }
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
            try manager.copyItem(at: source, to: target)
            Log.settings.info("Settings carried over from the macdock folder")
        } catch {
            let reason = error.localizedDescription
            Log.settings.error("Could not carry settings over: \(reason, privacy: .public)")
        }
    }
}
