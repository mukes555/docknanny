import Foundation
import Testing

@testable import macdock

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
        #expect(SystemDockMonitor.bundleIdentifiers(fromPersistentApps: entries)
            == ["com.googlecode.iterm2", "com.apple.systempreferences", "com.google.Chrome"])
    }

    /// Older Dock entries carry only a file URL. Calculator ships with every
    /// macOS, so the bundle on disk is a dependable fixture.
    @Test("An entry with only a file URL resolves through the bundle on disk")
    func fileURLFallback() {
        let entries = [
            tile(["file-data": ["_CFURLString": "file:///System/Applications/Calculator.app/", "_CFURLStringType": 15]])
        ]
        #expect(SystemDockMonitor.bundleIdentifiers(fromPersistentApps: entries) == ["com.apple.calculator"])
    }

    @Test("Malformed entries are skipped, not fatal")
    func malformedEntriesAreSkipped() {
        let entries: [[String: Any]] = [
            ["tile-type": "spacer-tile"],
            tile(["bundle-identifier": ""]),
            tile(["file-data": ["_CFURLString": "file:///nonexistent/Nothing.app/"]]),
            tile(["bundle-identifier": "com.apple.finder"])
        ]
        #expect(SystemDockMonitor.bundleIdentifiers(fromPersistentApps: entries) == ["com.apple.finder"])
    }

    @Test("A duplicated app appears once")
    func duplicatesCollapse() {
        let entries = [
            tile(["bundle-identifier": "com.apple.Safari"]),
            tile(["bundle-identifier": "com.apple.Safari"])
        ]
        #expect(SystemDockMonitor.bundleIdentifiers(fromPersistentApps: entries) == ["com.apple.Safari"])
    }

    @Test("Mirroring is on by default, and a file without the key gets it")
    func mirrorIsTheDefault() throws {
        #expect(Settings().mirrorSystemDock)
        let decoded = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
        #expect(decoded.mirrorSystemDock)
    }
}
