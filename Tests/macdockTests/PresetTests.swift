import Foundation
import Testing

@testable import macdock

@Suite("Presets and the settings file")
struct PresetTests {
    @Test("A preset changes the look and leaves pins, overrides and shortcuts alone")
    func presetsLeaveContentsAlone() {
        var settings = Settings()
        settings.pinnedBundleIdentifiers = ["com.example.one"]
        settings.pinnedOthers = ["file:///Users/nobody/Downloads/"]
        settings.mirrorSystemDock = false
        settings.setOverride(DisplayOverride(edge: .left), forDisplay: 4)
        settings.hotkeyModifiers = .optionCommand

        for preset in SettingsPreset.allCases where preset != .matchDock {
            var applied = settings
            preset.apply(to: &applied, dock: SystemDockMonitor.Snapshot())
            #expect(applied.pinnedBundleIdentifiers == settings.pinnedBundleIdentifiers)
            #expect(applied.pinnedOthers == settings.pinnedOthers)
            #expect(applied.perDisplay == settings.perDisplay)
            #expect(applied.hotkeyModifiers == .optionCommand)
            #expect(!applied.mirrorSystemDock)
        }
    }

    @Test("Match the Dock takes the Dock's edge, size, magnification and hiding")
    func matchDockReadsTheDock() {
        var dock = SystemDockMonitor.Snapshot()
        dock.edge = .left
        dock.tileSize = 52
        dock.magnifiedTileSize = 78
        dock.autoHides = true

        var settings = Settings()
        settings.mirrorSystemDock = false
        SettingsPreset.matchDock.apply(to: &settings, dock: dock)

        #expect(settings.edge == .left)
        #expect(settings.iconSize == 52)
        #expect(settings.isMagnificationEnabled)
        #expect(settings.magnificationScale == 1.5)
        #expect(settings.autoHide)
        #expect(settings.mirrorSystemDock)
    }

    @Test("Match the Dock with magnification off leaves the scale alone and turns it off")
    func matchDockWithoutMagnification() {
        var settings = Settings()
        settings.magnificationScale = 2
        SettingsPreset.matchDock.apply(to: &settings, dock: SystemDockMonitor.Snapshot())

        #expect(!settings.isMagnificationEnabled)
        #expect(settings.magnificationScale == 2)
    }

    @Test("The Dock's orientation preference reads as an edge, and nonsense as nil")
    func orientationParses() {
        #expect(DockEdge(dockOrientation: nil) == .bottom)
        #expect(DockEdge(dockOrientation: "left") == .left)
        #expect(DockEdge(dockOrientation: "right") == .right)
        #expect(DockEdge(dockOrientation: "top") == nil)
    }

    @Test("Export then import round-trips every setting, except that the welcome stays seen")
    @MainActor
    func exportImportRoundTrip() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "macdock-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let source = SettingsStore(directory: folder.appending(path: "a"), writeDelay: .seconds(60))
        source.settings.iconSize = 61
        source.settings.tint = .ember
        source.settings.pinnedBundleIdentifiers = ["com.example.exported"]
        source.settings.hasSeenWelcome = false

        let file = folder.appending(path: "exported.json")
        try source.export(to: file)

        let target = SettingsStore(directory: folder.appending(path: "b"), writeDelay: .seconds(60))
        target.settings.hasSeenWelcome = true
        try target.importSettings(from: file)

        #expect(target.settings.iconSize == 61)
        #expect(target.settings.tint == .ember)
        #expect(target.settings.pinnedBundleIdentifiers == ["com.example.exported"])
        #expect(target.settings.hasSeenWelcome)
    }

    @Test("Importing something that is not settings throws and changes nothing")
    @MainActor
    func badImportIsRejected() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "macdock-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let file = folder.appending(path: "junk.json")
        try Data("not json".utf8).write(to: file)

        let store = SettingsStore(directory: folder, writeDelay: .seconds(60))
        store.settings.iconSize = 33
        #expect(throws: (any Error).self) { try store.importSettings(from: file) }
        #expect(store.settings.iconSize == 33)
    }

    @Test("Reset restores defaults but keeps the welcome seen")
    @MainActor
    func resetKeepsWelcomeSeen() {
        let folder = FileManager.default.temporaryDirectory.appending(path: "macdock-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let store = SettingsStore(directory: folder, writeDelay: .seconds(60))
        store.settings.iconSize = 90
        store.settings.hasSeenWelcome = true
        store.resetToDefaults()

        #expect(store.settings.iconSize == Settings().iconSize)
        #expect(store.settings.hasSeenWelcome)
    }
}
