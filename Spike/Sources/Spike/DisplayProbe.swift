import AppKit

/// Phase 1 keys every dock panel by `CGDirectDisplayID`, so that id has to be
/// obtainable and stable for every attached screen.
@MainActor
enum DisplayProbe {
    static func run() -> ProbeResult {
        let question = "Can every screen be identified by a stable CGDirectDisplayID?"
        let screens = NSScreen.screens

        guard !screens.isEmpty else {
            return ProbeResult(
                name: "Display identity",
                question: question,
                outcome: .unavailable("NSScreen.screens is empty.")
            )
        }

        let unidentified = screens.filter { displayID(of: $0) == nil }
        let notes = screens.map(describe)

        guard unidentified.isEmpty else {
            return ProbeResult(
                name: "Display identity",
                question: question,
                outcome: .unavailable("\(unidentified.count) of \(screens.count) screens have no display id."),
                notes: notes
            )
        }

        return ProbeResult(
            name: "Display identity",
            question: question,
            outcome: .available("\(screens.count) screen(s), all identified."),
            notes: notes
        )
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }

    private static func describe(_ screen: NSScreen) -> String {
        let identifier = displayID(of: screen).map(String.init) ?? "unknown"
        let frame = screen.frame
        let role = screen == NSScreen.main ? " [main]" : ""
        let size = "\(Int(frame.width))x\(Int(frame.height))"
        let origin = "(\(Int(frame.origin.x)),\(Int(frame.origin.y)))"
        return "id \(identifier): \(size) at \(origin), scale \(screen.backingScaleFactor)x\(role)"
    }
}
