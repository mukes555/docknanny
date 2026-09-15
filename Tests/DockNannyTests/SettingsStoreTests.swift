import Foundation
import Testing

@testable import DockNanny

@Suite("The settings store")
@MainActor
struct SettingsStoreTests {
    @Test("A save that fails is reported, and a save that works clears the report")
    func saveFailureIsReported() throws {
        let nowhere = URL(filePath: "/dev/null/docknanny-cannot-exist", directoryHint: .isDirectory)
        let broken = SettingsStore(directory: nowhere, writeDelay: .zero)
        broken.settings.margin = 12
        broken.flush()
        #expect(broken.saveFailure != nil)

        let folder = FileManager.default.temporaryDirectory
            .appending(path: "docknanny-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let working = SettingsStore(directory: folder, writeDelay: .zero)
        working.settings.margin = 12
        working.flush()
        #expect(working.saveFailure == nil)
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "settings.json").path))
    }
}
