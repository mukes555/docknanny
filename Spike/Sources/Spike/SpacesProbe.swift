import AppKit

/// Per-display Space filtering is the one planned feature with no public API.
/// If these symbols are gone, the feature ships as a no-op and everything else
/// is unaffected, so this probe decides only the fate of Phase 4.
@MainActor
enum SpacesProbe {
    private static let name = "Per-display Spaces (private SkyLight SPI)"
    private static let question = "Can we tell which Space is active on each display?"

    static func run(symbols: SystemSymbols) -> ProbeResult {
        guard let connect = symbols.mainConnectionID else {
            return degrade("CGSMainConnectionID did not resolve.")
        }
        guard let activeSpace = symbols.activeSpace else {
            return degrade("CGSGetActiveSpace did not resolve.")
        }
        guard let displaySpaces = symbols.managedDisplaySpaces else {
            return degrade("CGSCopyManagedDisplaySpaces did not resolve.")
        }

        let connection = connect()
        guard connection != 0 else {
            return degrade("Window server connection id was 0.")
        }

        let currentSpace = activeSpace(connection)
        guard let raw = displaySpaces(connection)?.takeRetainedValue(),
              let displays = raw as? [[String: Any]], !displays.isEmpty else {
            return degrade("CGSCopyManagedDisplaySpaces returned nothing usable.")
        }

        var notes = ["active space id: \(currentSpace)"]
        notes.append(contentsOf: displays.map(describe))

        return ProbeResult(
            name: name,
            question: question,
            outcome: .available("\(displays.count) managed display(s) reported."),
            notes: notes
        )
    }

    private static func describe(_ display: [String: Any]) -> String {
        let identifier = display["Display Identifier"] as? String ?? "unknown"
        let spaces = display["Spaces"] as? [[String: Any]] ?? []
        let ids = spaces.compactMap { $0["id64"] as? UInt64 }
        return "display \(identifier): \(spaces.count) space(s) \(ids)"
    }

    /// Space awareness failing is a downgrade, never a blocker: the fallback is
    /// to show every window regardless of Space.
    private static func degrade(_ reason: String) -> ProbeResult {
        ProbeResult(
            name: name,
            question: question,
            outcome: .degraded(reason),
            notes: ["Phase 4 would ship as NoOpSpaceFilter. Phases 1 to 3 unaffected."]
        )
    }
}
