import AppKit
import ApplicationServices

/// MultiDock matched AX windows to window-server windows by title, then fell
/// back to comparing frames within 10pt, and documented the result as
/// unreliable. This probe checks whether the direct accessor works instead.
@MainActor
enum WindowIDProbe {
    private static let name = "AX to CGWindowID resolution"
    private static let question = "Can a CGWindowID be read straight off an AX window element?"

    static func run(symbols: SystemSymbols) -> ProbeResult {
        guard AXIsProcessTrusted() else {
            return ProbeResult(
                name: name,
                question: question,
                outcome: .skipped("This binary is not trusted for Accessibility."),
                notes: [
                    "Grant it in System Settings > Privacy & Security > Accessibility,",
                    "then re-run. The spike binary appears as 'Spike'."
                ]
            )
        }

        guard let resolve = symbols.windowIDForElement else {
            return ProbeResult(
                name: name,
                question: question,
                outcome: .unavailable("_AXUIElementGetWindow did not resolve at runtime.")
            )
        }

        let tally = survey(using: resolve)

        guard tally.total > 0 else {
            return ProbeResult(
                name: name,
                question: question,
                outcome: .skipped("No AX windows found. Open a couple of apps and re-run."),
                notes: tally.notes
            )
        }

        let rate = Int((Double(tally.resolved) / Double(tally.total)) * 100)
        let detail = "\(tally.resolved)/\(tally.total) windows resolved (\(rate)%)."

        if tally.resolved == tally.total {
            return ProbeResult(name: name, question: question,
                               outcome: .available(detail), notes: tally.notes)
        }
        return ProbeResult(name: name, question: question,
                           outcome: .degraded(detail + " Needs a fallback for the remainder."),
                           notes: tally.notes)
    }

    private struct Tally {
        var total = 0
        var resolved = 0
        var notes: [String] = []
    }

    private static func survey(using resolve: AXUIElementGetWindowFunction) -> Tally {
        var tally = Tally()

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isTerminated {
            let windows = axWindows(forProcess: app.processIdentifier)
            guard !windows.isEmpty else { continue }

            var resolvedHere = 0
            for window in windows {
                var identifier = CGWindowID(0)
                if resolve(window, &identifier) == .success, identifier != 0 {
                    resolvedHere += 1
                }
            }

            tally.total += windows.count
            tally.resolved += resolvedHere
            let label = app.localizedName ?? "pid \(app.processIdentifier)"
            tally.notes.append("\(label): \(resolvedHere)/\(windows.count)")
        }

        return tally
    }

    private static func axWindows(forProcess pid: pid_t) -> [AXUIElement] {
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            application, kAXWindowsAttribute as CFString, &value
        )
        guard status == .success, let windows = value as? [AXUIElement] else { return [] }
        return windows
    }
}
