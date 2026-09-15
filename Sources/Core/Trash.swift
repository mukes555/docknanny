import AppKit

/// The user's Trash, as far as a dock needs to know about it.
///
/// Its contents sit behind Full Disk Access, which DockNanny does not want and
/// which macOS would not even prompt for. The entry count is directory
/// metadata rather than a listing, so it is readable without that access,
/// and it is all the tile needs: full or empty.
enum Trash {
    static let url = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".Trash", directoryHint: .isDirectory)

    nonisolated static func isFull() -> Bool {
        var request = attrlist()
        request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        request.dirattr = attrgroup_t(ATTR_DIR_ENTRYCOUNT)

        let path = NSHomeDirectory() + "/.Trash"
        var reply = EntryCountReply()
        let status = getattrlist(path, &request, &reply, MemoryLayout<EntryCountReply>.size, UInt32(FSOPT_NOFOLLOW))
        guard status == 0 else { return false }
        return Int(reply.entries) > housekeepingEntries(in: path)
    }

    /// Finder keeps its own files in the Trash folder (a .DS_Store once the
    /// Trash has been looked at, a .localized marker) and they survive
    /// emptying, so they must not count as contents. Listing the folder is
    /// not allowed without Full Disk Access; asking after a known name is.
    nonisolated private static func housekeepingEntries(in path: String) -> Int {
        [".DS_Store", ".localized"].filter { access(path + "/" + $0, F_OK) == 0 }.count
    }

    /// The reply buffer: its own length, then the requested attribute.
    private struct EntryCountReply {
        var length: UInt32 = 0
        var entries: UInt32 = 0
    }

    @MainActor
    static func open() {
        NSWorkspace.shared.open(url)
    }

    /// Asks Finder to do it. Finder shows its own "permanently erase?"
    /// confirmation and owns the deletion, so nothing here is irreversible on
    /// its own. The first use raises the Automation prompt for controlling
    /// Finder; declining it leaves the Trash alone, and Finder answers every
    /// later request the same way without asking again. So a request that
    /// fails opens the Trash instead: the person can empty it there, and
    /// sees why the menu item did nothing.
    @MainActor
    static func emptyViaFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application \"Finder\" to empty trash"]
        process.standardError = Pipe()
        // The handler holds the process until it exits, so the child is
        // reaped rather than left a zombie when this scope ends.
        process.terminationHandler = { finished in
            finished.terminationHandler = nil
            guard finished.terminationStatus != 0 else { return }
            let output = (finished.standardError as? Pipe)?.fileHandleForReading.readDataToEndOfFile() ?? Data()
            let reason = (String(bytes: output, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in
                Log.workspace.error("Finder did not empty the Trash: \(reason, privacy: .public)")
                open()
            }
        }
        do {
            try process.run()
        } catch {
            let reason = error.localizedDescription
            Log.workspace.error("Could not ask Finder to empty the Trash: \(reason, privacy: .public)")
            open()
        }
    }

    /// What a drop on the Trash tile does: the same move the Finder makes,
    /// which is undoable there and touches nothing permanently.
    @MainActor
    static func moveToTrash(_ urls: [URL]) {
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                let reason = error.localizedDescription
                Log.workspace.error("Could not move an item to the Trash: \(reason, privacy: .public)")
            }
        }
    }
}
