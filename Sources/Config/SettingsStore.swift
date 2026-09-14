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
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoder.encode(settings).write(to: fileURL, options: .atomic)
        } catch {
            Log.settings.error("Could not save settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// A settings file that cannot be read is replaced by defaults rather than
    /// blocking launch. Losing preferences is recoverable; a dock that will not
    /// start is not.
    private static func load(from url: URL) -> Settings {
        guard let data = try? Data(contentsOf: url) else { return Settings() }
        do {
            return try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            Log.settings.error("Settings unreadable, using defaults: \(error.localizedDescription, privacy: .public)")
            return Settings()
        }
    }

    private static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let root = base.first ?? URL.temporaryDirectory
        return root.appending(path: "macdock")
    }
}
