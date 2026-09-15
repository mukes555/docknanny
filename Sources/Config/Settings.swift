import CoreGraphics
import Foundation

/// Everything configurable, in one value type.
///
/// The global list is deliberately held flat. Depth lives on the per-display
/// axis instead, in ``DisplayOverride``, because "this screen is for comms and
/// that one is for tools" is the thing DockNanny can do that a single-dock
/// product cannot, while a longer global list is the thing every dock already
/// has too much of.
struct Settings: Codable, Equatable, Sendable {
    // Layout
    var edge: DockEdge = .bottom
    var alignment: DockAlignment = .center
    var margin: Double = 8

    // Appearance
    var brandPalette: BrandPalette = .lime
    var iconSize: Double = 48
    var itemSpacing: Double = 6
    var chromeStyle: ChromeStyle = .glass
    var indicatorStyle: IndicatorStyle = .dot
    var tint: DockTint = .none

    // Magnification. One magnitude serves both modes; the mode changes how far
    // the effect reaches, not how large the peak is.
    var isMagnificationEnabled: Bool = false
    var magnificationScale: Double = 1.45

    // Behaviour
    var showRunningApps: Bool = true
    /// The display the system Dock is on already has a dock. Off by request
    /// only: two docks on one screen is the thing this app exists to avoid.
    var skipSystemDockDisplay: Bool = true
    var autoHide: Bool = false
    var autoHideDelay: Double = 0.15
    var activeClickBehavior: ActiveClickBehavior = .doNothing
    /// Nudge windows that open or zoom into a dock's space out of it. Off
    /// until asked for: it needs Accessibility and moves other apps' windows.
    var keepWindowsClear: Bool = false
    var launchAtLogin: Bool = false
    var hasSeenWelcome: Bool = false

    // Keyboard
    var tileHotkeysEnabled: Bool = true
    var hidingHotkeyEnabled: Bool = true
    var hotkeyModifiers: HotkeyModifiers = .controlOption

    // Contents
    /// Follow the system Dock's pinned apps and order. This is the default
    /// because a dock on every display should be the same dock, not a second
    /// one that opens something different from the same position.
    var mirrorSystemDock: Bool = true
    /// Bundle identifiers in order, with ``DockItem/spacerIdentifier`` for gaps.
    var pinnedBundleIdentifiers: [String] = Settings.defaultPins
    /// The section after the apps: folder and document URLs as strings, with
    /// ``DockItem/spacerIdentifier`` for gaps.
    var pinnedOthers: [String] = []
    var hiddenBundleIdentifiers: [String] = []
    var showTrash: Bool = true

    /// Per-display deviations, keyed by a ``DisplayKey`` that survives
    /// reconnection.
    var perDisplay: [String: DisplayOverride] = [:]

    enum CodingKeys: String, CodingKey {
        case edge, alignment, margin
        case brandPalette, iconSize, itemSpacing, chromeStyle, indicatorStyle, tint
        case isMagnificationEnabled, magnificationScale
        case showRunningApps, skipSystemDockDisplay, autoHide, autoHideDelay
        case activeClickBehavior, keepWindowsClear, launchAtLogin, hasSeenWelcome
        case tileHotkeysEnabled, hidingHotkeyEnabled, hotkeyModifiers
        case mirrorSystemDock, pinnedBundleIdentifiers, pinnedOthers, hiddenBundleIdentifiers, showTrash
        case perDisplay
    }

    static let defaultPins = [
        "com.apple.finder",
        "com.apple.Safari",
        "com.apple.Terminal",
        "com.apple.systempreferences"
    ]

    func resolved(for display: Display) -> ResolvedDockConfiguration {
        let override = self.override(forDisplay: display.id)
        let inheritedEnabled = display.hasSystemDock ? !skipSystemDockDisplay : true

        return ResolvedDockConfiguration(
            isEnabled: override.isEnabled ?? inheritedEnabled,
            edge: override.edge ?? edge,
            alignment: override.alignment ?? alignment,
            margin: CGFloat(margin.clamped(to: Limits.margin)),
            iconSize: CGFloat((override.iconSize ?? iconSize).clamped(to: Limits.iconSize)),
            itemSpacing: CGFloat(itemSpacing.clamped(to: Limits.itemSpacing)),
            chromeStyle: chromeStyle,
            indicatorStyle: indicatorStyle,
            tint: override.tint ?? tint,
            isMagnificationEnabled: isMagnificationEnabled,
            magnificationScale: CGFloat(magnificationScale.clamped(to: Limits.scale)),
            showRunningApps: override.showRunningApps ?? showRunningApps,
            autoHide: override.autoHide ?? autoHide,
            autoHideDelay: autoHideDelay.clamped(to: Limits.revealDelay),
            activeClickBehavior: activeClickBehavior,
            pinnedBundleIdentifiers: override.pinnedBundleIdentifiers ?? pinnedBundleIdentifiers,
            pinnedOthers: pinnedOthers,
            showTrash: showTrash,
            hiddenBundleIdentifiers: Set(hiddenBundleIdentifiers),
            allowedBundleIdentifiers: override.allowedBundleIdentifiers
        )
    }

    /// Reads the stable key first, then the session-id key a pre-``DisplayKey``
    /// file would have used, so upgrading keeps a user's per-display setup.
    func override(forDisplay id: CGDirectDisplayID) -> DisplayOverride {
        perDisplay[DisplayKey(displayID: id).rawValue]
            ?? perDisplay[DisplayKey.legacy(displayID: id)]
            ?? DisplayOverride()
    }

    /// Always writes the stable key, which migrates a legacy entry on first
    /// change without a migration pass.
    mutating func setOverride(_ override: DisplayOverride, forDisplay id: CGDirectDisplayID) {
        perDisplay.removeValue(forKey: DisplayKey.legacy(displayID: id))

        let key = DisplayKey(displayID: id).rawValue
        if override.isDefault {
            perDisplay.removeValue(forKey: key)
        } else {
            perDisplay[key] = override
        }
    }
}

/// A per-display deviation. Every field is optional; nil means "inherit".
///
/// This is where the product's depth lives, so it is allowed to grow where the
/// global list is not.
struct DisplayOverride: Codable, Equatable, Sendable {
    var isEnabled: Bool?
    var edge: DockEdge?
    var alignment: DockAlignment?
    var iconSize: Double?
    var showRunningApps: Bool?
    var autoHide: Bool?
    var tint: DockTint?

    /// A different set of pinned apps for this screen, which is the whole
    /// point: this display is for one kind of work.
    var pinnedBundleIdentifiers: [String]?

    /// nil shows every app. A non-nil list shows only those.
    var allowedBundleIdentifiers: [String]?

    enum CodingKeys: String, CodingKey {
        case isEnabled, edge, alignment, iconSize, showRunningApps, autoHide, tint
        case pinnedBundleIdentifiers, allowedBundleIdentifiers
    }

    var isDefault: Bool {
        self == DisplayOverride()
    }
}

/// Global settings collapsed with one display's overrides, so panel code never
/// reasons about inheritance.
struct ResolvedDockConfiguration: Equatable, Sendable {
    let isEnabled: Bool
    let edge: DockEdge
    let alignment: DockAlignment
    let margin: CGFloat
    let iconSize: CGFloat
    let itemSpacing: CGFloat
    let chromeStyle: ChromeStyle
    let indicatorStyle: IndicatorStyle
    let tint: DockTint
    let isMagnificationEnabled: Bool
    let magnificationScale: CGFloat
    let showRunningApps: Bool
    let autoHide: Bool
    let autoHideDelay: Double
    let activeClickBehavior: ActiveClickBehavior
    let pinnedBundleIdentifiers: [String]
    let pinnedOthers: [String]
    let showTrash: Bool
    let hiddenBundleIdentifiers: Set<String>
    let allowedBundleIdentifiers: [String]?

    func allows(bundleIdentifier: String) -> Bool {
        guard !hiddenBundleIdentifiers.contains(bundleIdentifier) else { return false }
        guard let allowedBundleIdentifiers else { return true }
        return allowedBundleIdentifiers.contains(bundleIdentifier)
    }
}
