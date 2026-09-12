import Foundation

/// What a probe concluded, in the only vocabulary Phase 0 cares about:
/// can the real app build on this, or does it need a fallback path?
enum ProbeOutcome {
    case available(String)
    case degraded(String)
    case unavailable(String)
    case skipped(String)

    var symbol: String {
        switch self {
        case .available: "PASS"
        case .degraded: "WARN"
        case .unavailable: "FAIL"
        case .skipped: "SKIP"
        }
    }

    var detail: String {
        switch self {
        case .available(let text), .degraded(let text),
             .unavailable(let text), .skipped(let text):
            text
        }
    }
}

struct ProbeResult {
    let name: String
    /// The decision this probe informs, so a failure reads as a consequence
    /// rather than a bare error string.
    let question: String
    let outcome: ProbeOutcome
    var notes: [String] = []
}

enum ProbeReport {
    static func render(_ results: [ProbeResult]) -> String {
        var lines = [
            "",
            "macdock Phase 0 capability probe",
            "  macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            String(repeating: "=", count: 66),
            ""
        ]

        for result in results {
            lines.append("[\(result.outcome.symbol)] \(result.name)")
            lines.append("       q: \(result.question)")
            lines.append("       > \(result.outcome.detail)")
            lines.append(contentsOf: result.notes.map { "         - \($0)" })
            lines.append("")
        }

        lines.append(String(repeating: "=", count: 66))
        lines.append(summary(for: results))
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func summary(for results: [ProbeResult]) -> String {
        let blocking = results.filter { if case .unavailable = $0.outcome { return true } else { return false } }
        guard blocking.isEmpty else {
            let names = blocking.map(\.name).joined(separator: ", ")
            return "BLOCKED: \(names). The plan needs revising before Phase 1."
        }

        let degraded = results.filter { if case .degraded = $0.outcome { return true } else { return false } }
        guard degraded.isEmpty else {
            return "PROCEED with fallbacks: \(degraded.map(\.name).joined(separator: ", "))"
        }
        return "ALL CLEAR. Phase 1 can proceed as planned."
    }
}
