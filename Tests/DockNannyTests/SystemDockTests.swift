import Foundation
import Testing

@testable import DockNanny

@Suite("System Dock mirroring")
struct SystemDockTests {
    private func tile(_ fields: [String: Any]) -> [String: Any] {
        ["tile-data": fields, "tile-type": "file-tile"]
    }

    @Test("Bundle identifiers are read in the Dock's order")
    func orderIsPreserved() {
        let entries = [
            tile(["bundle-identifier": "com.googlecode.iterm2"]),
            tile(["bundle-identifier": "com.apple.systempreferences"]),
            tile(["bundle-identifier": "com.google.Chrome"])
        ]
        #expect(SystemDockTiles.pins(fromPersistentApps: entries)
            == ["com.googlecode.iterm2", "com.apple.systempreferences", "com.google.Chrome"])
    }

    /// Older Dock entries carry only a file URL. Calculator ships with every
    /// macOS, so the bundle on disk is a dependable fixture.
    @Test("An entry with only a file URL resolves through the bundle on disk")
    func fileURLFallback() {
        let entries = [
            tile(["file-data": ["_CFURLString": "file:///System/Applications/Calculator.app/", "_CFURLStringType": 15]])
        ]
        #expect(SystemDockTiles.pins(fromPersistentApps: entries) == ["com.apple.calculator"])
    }

    @Test("Malformed entries are skipped, not fatal")
    func malformedEntriesAreSkipped() {
        let entries: [[String: Any]] = [
            tile(["bundle-identifier": ""]),
            tile(["file-data": ["_CFURLString": "file:///nonexistent/Nothing.app/"]]),
            ["tile-type": "file-tile"],
            tile(["bundle-identifier": "com.apple.finder"])
        ]
        #expect(SystemDockTiles.pins(fromPersistentApps: entries) == ["com.apple.finder"])
    }

    @Test("A spacer becomes the spacer sentinel, in place")
    func spacersKeepTheirPlace() {
        let entries: [[String: Any]] = [
            tile(["bundle-identifier": "a"]),
            ["tile-type": "spacer-tile"],
            ["tile-type": "small-spacer-tile"],
            tile(["bundle-identifier": "b"])
        ]
        #expect(SystemDockTiles.pins(fromPersistentApps: entries)
            == ["a", DockItem.spacerIdentifier, DockItem.spacerIdentifier, "b"])
    }

    @Test("Folders in the others section are read as file URLs, whether stored as URL or path")
    func othersAreFileURLs() {
        let entries: [[String: Any]] = [
            ["tile-type": "directory-tile", "tile-data": [
                "file-data": ["_CFURLString": "file:///Users/nobody/Downloads/", "_CFURLStringType": 15]
            ]],
            ["tile-type": "file-tile", "tile-data": [
                "file-data": ["_CFURLString": "/Users/nobody/Notes.txt", "_CFURLStringType": 0]
            ]],
            ["tile-type": "url-tile", "tile-data": ["url": ["_CFURLString": "https://example.com"]]],
            ["tile-type": "spacer-tile"]
        ]
        #expect(SystemDockTiles.others(fromPersistentOthers: entries)
            == ["file:///Users/nobody/Downloads/", "file:///Users/nobody/Notes.txt", DockItem.spacerIdentifier])
    }

    @Test("The Trash is on by default, and a file without the key keeps it")
    func trashIsTheDefault() throws {
        #expect(Settings().showTrash)
        let decoded = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
        #expect(decoded.showTrash)
        #expect(decoded.pinnedOthers.isEmpty)
    }

    @Test("A duplicated app appears once")
    func duplicatesCollapse() {
        let entries = [
            tile(["bundle-identifier": "com.apple.Safari"]),
            tile(["bundle-identifier": "com.apple.Safari"])
        ]
        #expect(SystemDockTiles.pins(fromPersistentApps: entries) == ["com.apple.Safari"])
    }

    @Test("Mirroring is on by default, and a file without the key gets it")
    func mirrorIsTheDefault() throws {
        #expect(Settings().mirrorSystemDock)
        let decoded = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
        #expect(decoded.mirrorSystemDock)
    }

    @Test("One malformed tile entry costs that entry, not the list")
    func malformedTileEntryIsSkipped() {
        let mixed: [Any] = [tile(["bundle-identifier": "com.apple.Safari"]), "junk", 5, ["tile-type": "spacer-tile"]]

        #expect(SystemDockMonitor.tiles(from: mixed).count == 2)
        #expect(SystemDockMonitor.tiles(from: "junk").isEmpty)
        #expect(SystemDockMonitor.tiles(from: nil).isEmpty)
    }
}
