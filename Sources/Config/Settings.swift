import CoreGraphics
import Foundation

/// Everything configurable, in one value type.
///
/// The settings UI is generated from this, so adding an option means adding a
/// property here and nothing else.
struct Settings: Codable, Equatable, Sendable {
    var edge: DockEdge = .bottom
    var iconSize: Double = 48
    var margin: Double = 8
    var itemSpacing: Double = 6
    var showRunningApps: Bool = true
    var showOnPrimaryDisplay: Bool = true
    var pinnedBundleIdentifiers: [String] = Settings.defaultPins

    /// Per-display overrides, keyed by `CGDirectDisplayID` rendered as a string
    /// because JSON object keys cannot be numbers.
    var perDisplay: [String: DisplayOverride] = [:]

    static let defaultPins = [
        "com.apple.finder",
        "com.apple.Safari",
        "com.apple.Terminal",
        "com.apple.systempreferences"
    ]

    func resolved(for display: Display) -> ResolvedDockConfiguration {
        let override = perDisplay[String(display.id)]
        let enabled = override?.isEnabled ?? (display.isPrimary ? showOnPrimaryDisplay : true)

        return ResolvedDockConfiguration(
            isEnabled: enabled,
            edge: override?.edge ?? edge,
            iconSize: CGFloat(override?.iconSize ?? iconSize),
            margin: CGFloat(margin),
            itemSpacing: CGFloat(itemSpacing),
            showRunningApps: override?.showRunningApps ?? showRunningApps,
            allowedBundleIdentifiers: override?.allowedBundleIdentifiers
        )
    }
}

/// A per-display deviation. Every field is optional; nil means "inherit".
struct DisplayOverride: Codable, Equatable, Sendable {
    var isEnabled: Bool?
    var edge: DockEdge?
    var iconSize: Double?
    var showRunningApps: Bool?

    /// nil shows every app. A non-nil list shows only those, which is how one
    /// screen carries comms and another carries tools.
    var allowedBundleIdentifiers: [String]?
}

/// Global settings collapsed with one display's overrides, so panel code never
/// has to reason about inheritance.
struct ResolvedDockConfiguration: Equatable, Sendable {
    let isEnabled: Bool
    let edge: DockEdge
    let iconSize: CGFloat
    let margin: CGFloat
    let itemSpacing: CGFloat
    let showRunningApps: Bool
    let allowedBundleIdentifiers: [String]?

    func allows(bundleIdentifier: String) -> Bool {
        guard let allowedBundleIdentifiers else { return true }
        return allowedBundleIdentifiers.contains(bundleIdentifier)
    }
}
