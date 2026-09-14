import OSLog

/// Subsystem-scoped loggers.
///
/// Categories match the module layout so `log stream --predicate` can follow
/// one subsystem without the others drowning it out.
enum Log {
    private static let subsystem = "app.macdock"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let display = Logger(subsystem: subsystem, category: "display")
    static let workspace = Logger(subsystem: subsystem, category: "workspace")
    static let panel = Logger(subsystem: subsystem, category: "panel")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let privateAPI = Logger(subsystem: subsystem, category: "private-api")
    /// Diagnostic runs (`--probe-windows`), read back with `log show`.
    static let probe = Logger(subsystem: subsystem, category: "probe")
}
