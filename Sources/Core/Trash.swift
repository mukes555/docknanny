import AppKit

/// The user's Trash, as far as a dock needs to know about it.
///
/// Its contents sit behind Full Disk Access, which macdock does not want and
/// which macOS would not even prompt for. The entry count is directory
/// metadata rather than a listing, so it is readable without that access,
/// and it is all the tile needs: full or empty.
enum Trash {
    static let url = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".Trash", directoryHint: .isDirectory)

    nonisolated static func isFull() -> Bool {
        var request = attrlist()
        request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        request.dirattr = attrgroup_t(ATTR_DIR_ENTRYCOUNT)

        var reply = EntryCountReply()
        let status = getattrlist(
            NSHomeDirectory() + "/.Trash", &request, &reply,
            MemoryLayout<EntryCountReply>.size, UInt32(FSOPT_NOFOLLOW)
        )
        return status == 0 && reply.entries > 0
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
    /// Finder; declining it leaves the Trash alone.
    @MainActor
    static func emptyViaFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application \"Finder\" to empty trash"]
        do {
            try process.run()
        } catch {
            let reason = error.localizedDescription
            Log.workspace.error("Could not ask Finder to empty the Trash: \(reason, privacy: .public)")
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
