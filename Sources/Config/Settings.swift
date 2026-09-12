import CoreGraphics
import Foundation

/// Everything configurable, in one value type.
///
/// The settings UI is generated from this, so adding an option means adding a
/// property here and a control that binds to it, never a third place to keep
/// in sync.
struct Settings: Codable, Equatable, Sendable {
    // Layout
    var edge: DockEdge = .bottom
    var alignment: DockAlignment = .center
    var margin: Double = 8

    // Appearance
    var iconSize: Double = 48
    var itemSpacing: Double = 6
    var chromeStyle: ChromeStyle = .glass
    var chromeOpacity: Double = 1
    var cornerRadiusScale: Double = 0.28
    var indicatorStyle: IndicatorStyle = .dot

    // Magnification
    var isMagnificationEnabled: Bool = false
    var magnificationScale: Double = 1.6
    var hoverScale: Double = 1.12

    // Behaviour
    var showRunningApps: Bool = true
    var showOnPrimaryDisplay: Bool = true
    var autoHide: Bool = false
    var autoHideDelay: Double = 0.15
    var activeClickBehavior: ActiveClickBehavior = .hide
    var launchAtLogin: Bool = false
    var hasSeenWelcome: Bool = false

    // Contents
    var pinnedBundleIdentifiers: [String] = Settings.defaultPins
    var hiddenBundleIdentifiers: [String] = []

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
        let inheritedEnabled = display.isPrimary ? showOnPrimaryDisplay : true

        return ResolvedDockConfiguration(
            isEnabled: override?.isEnabled ?? inheritedEnabled,
            edge: override?.edge ?? edge,
            alignment: override?.alignment ?? alignment,
            margin: CGFloat(margin.clamped(to: Limits.margin)),
            iconSize: CGFloat((override?.iconSize ?? iconSize).clamped(to: Limits.iconSize)),
            itemSpacing: CGFloat(itemSpacing.clamped(to: Limits.itemSpacing)),
            chromeStyle: chromeStyle,
            chromeOpacity: chromeOpacity.clamped(to: Limits.chromeOpacity),
            cornerRadiusScale: cornerRadiusScale.clamped(to: Limits.cornerRadiusScale),
            indicatorStyle: indicatorStyle,
            isMagnificationEnabled: isMagnificationEnabled,
            magnificationScale: CGFloat(magnificationScale.clamped(to: Limits.scale)),
            hoverScale: CGFloat(hoverScale.clamped(to: Limits.scale)),
            showRunningApps: override?.showRunningApps ?? showRunningApps,
            autoHide: autoHide,
            autoHideDelay: autoHideDelay.clamped(to: Limits.revealDelay),
            activeClickBehavior: activeClickBehavior,
            hiddenBundleIdentifiers: Set(hiddenBundleIdentifiers),
            allowedBundleIdentifiers: override?.allowedBundleIdentifiers
        )
    }

    func override(forDisplay id: CGDirectDisplayID) -> DisplayOverride {
        perDisplay[String(id)] ?? DisplayOverride()
    }

    mutating func setOverride(_ override: DisplayOverride, forDisplay id: CGDirectDisplayID) {
        perDisplay[String(id)] = override
    }
}

/// A per-display deviation. Every field is optional; nil means "inherit".
///
/// Only options that are genuinely per-screen live here. Making every setting
/// overridable doubles the surface area and buys almost nothing.
struct DisplayOverride: Codable, Equatable, Sendable {
    var isEnabled: Bool?
    var edge: DockEdge?
    var alignment: DockAlignment?
    var iconSize: Double?
    var showRunningApps: Bool?

    /// nil shows every app. A non-nil list shows only those, which is how one
    /// screen carries comms and another carries tools.
    var allowedBundleIdentifiers: [String]?

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
    let chromeOpacity: Double
    let cornerRadiusScale: Double
    let indicatorStyle: IndicatorStyle
    let isMagnificationEnabled: Bool
    let magnificationScale: CGFloat
    let hoverScale: CGFloat
    let showRunningApps: Bool
    let autoHide: Bool
    let autoHideDelay: Double
    let activeClickBehavior: ActiveClickBehavior
    let hiddenBundleIdentifiers: Set<String>
    let allowedBundleIdentifiers: [String]?

    func allows(bundleIdentifier: String) -> Bool {
        guard !hiddenBundleIdentifiers.contains(bundleIdentifier) else { return false }
        guard let allowedBundleIdentifiers else { return true }
        return allowedBundleIdentifiers.contains(bundleIdentifier)
    }
}

extension Settings {
    /// Tolerant decoding.
    ///
    /// Swift's synthesised `Decodable` ignores property default values and
    /// throws on any missing key, so adding one setting would make every
    /// existing settings file unreadable and silently reset the user's pins,
    /// their per-display overrides, everything. Each key is therefore decoded
    /// independently and falls back to its default.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()

        func value<Value: Decodable>(_ key: CodingKeys, _ default: Value) -> Value {
            (try? container.decodeIfPresent(Value.self, forKey: key)) .flatMap { $0 } ?? `default`
        }

        edge = value(.edge, fallback.edge)
        alignment = value(.alignment, fallback.alignment)
        margin = value(.margin, fallback.margin)

        iconSize = value(.iconSize, fallback.iconSize)
        itemSpacing = value(.itemSpacing, fallback.itemSpacing)
        chromeStyle = value(.chromeStyle, fallback.chromeStyle)
        chromeOpacity = value(.chromeOpacity, fallback.chromeOpacity)
        cornerRadiusScale = value(.cornerRadiusScale, fallback.cornerRadiusScale)
        indicatorStyle = value(.indicatorStyle, fallback.indicatorStyle)

        isMagnificationEnabled = value(.isMagnificationEnabled, fallback.isMagnificationEnabled)
        magnificationScale = value(.magnificationScale, fallback.magnificationScale)
        hoverScale = value(.hoverScale, fallback.hoverScale)

        showRunningApps = value(.showRunningApps, fallback.showRunningApps)
        showOnPrimaryDisplay = value(.showOnPrimaryDisplay, fallback.showOnPrimaryDisplay)
        autoHide = value(.autoHide, fallback.autoHide)
        autoHideDelay = value(.autoHideDelay, fallback.autoHideDelay)
        activeClickBehavior = value(.activeClickBehavior, fallback.activeClickBehavior)
        launchAtLogin = value(.launchAtLogin, fallback.launchAtLogin)
        hasSeenWelcome = value(.hasSeenWelcome, fallback.hasSeenWelcome)

        pinnedBundleIdentifiers = value(.pinnedBundleIdentifiers, fallback.pinnedBundleIdentifiers)
        hiddenBundleIdentifiers = value(.hiddenBundleIdentifiers, fallback.hiddenBundleIdentifiers)
        // Decoded entry by entry: one corrupt display override should cost the
        // user that display's settings, not every display's.
        perDisplay = Self.decodePerDisplay(from: container) ?? fallback.perDisplay
    }
}

extension Settings {
    /// Bounds every geometry value, shared by the resolver and by the sliders so
    /// the limit exists once rather than in each control.
    enum Limits {
        static let iconSize: ClosedRange<Double> = 24...96
        static let itemSpacing: ClosedRange<Double> = 0...24
        static let margin: ClosedRange<Double> = 0...60
        static let scale: ClosedRange<Double> = 1.0...2.5
        static let chromeOpacity: ClosedRange<Double> = 0.2...1
        static let cornerRadiusScale: ClosedRange<Double> = 0...0.5
        static let revealDelay: ClosedRange<Double> = 0...1.5
    }

    private static func decodePerDisplay(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> [String: DisplayOverride]? {
        guard let entries = try? container.decodeIfPresent(
            [String: FailableOverride].self, forKey: .perDisplay
        ) else {
            return nil
        }
        return entries.compactMapValues(\.value)
    }
}

/// Decodes a display override, yielding nil instead of throwing when the entry
/// is malformed. Without this a single bad key aborts the whole dictionary.
private struct FailableOverride: Decodable {
    let value: DisplayOverride?

    init(from decoder: any Decoder) throws {
        value = try? DisplayOverride(from: decoder)
    }
}

extension Double {
    /// A settings file is user-editable, so it can carry infinities and NaN as
    /// well as absurd finite numbers. The isFinite guard is load-bearing:
    /// min(max(.nan, low), high) is .nan in Swift, and a NaN reaching
    /// NSPanel.setFrame is not recoverable.
    func clamped(to range: ClosedRange<Double>) -> Double {
        guard isFinite else { return range.lowerBound }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
