// swift-tools-version: 6.2
import PackageDescription

// Phase 0 spike. Throwaway by design: it answers "do the APIs macdock needs
// still work on this machine's macOS?" before any architecture depends on them.
let package = Package(
    name: "Spike",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Spike",
            path: "Sources/Spike",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
