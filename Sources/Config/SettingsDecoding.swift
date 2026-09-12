import Foundation

extension Settings {
    /// Bounds every value a hand-edited file can carry, shared by the resolver
    /// and by the sliders so the limit exists once rather than in each control.
    enum Limits {
        static let iconSize: ClosedRange<Double> = 24...96
        static let itemSpacing: ClosedRange<Double> = 0...24
        static let margin: ClosedRange<Double> = 0...60
        static let scale: ClosedRange<Double> = 1.0...2.5
        static let revealDelay: ClosedRange<Double> = 0...1.5
    }

    /// Tolerant decoding.
    ///
    /// Swift's synthesised `Decodable` ignores property default values and
    /// throws on any missing key, so adding one setting would make every
    /// existing settings file unreadable and silently reset the user's pins,
    /// their per-display overrides, everything. Each key is decoded
    /// independently and falls back to its default.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()

        func value<Value: Decodable>(_ key: CodingKeys, _ default: Value) -> Value {
            (try? container.decodeIfPresent(Value.self, forKey: key)).flatMap { $0 } ?? `default`
        }

        edge = value(.edge, fallback.edge)
        alignment = value(.alignment, fallback.alignment)
        margin = value(.margin, fallback.margin)

        iconSize = value(.iconSize, fallback.iconSize)
        itemSpacing = value(.itemSpacing, fallback.itemSpacing)
        chromeStyle = value(.chromeStyle, fallback.chromeStyle)
        indicatorStyle = value(.indicatorStyle, fallback.indicatorStyle)
        tint = value(.tint, fallback.tint)

        isMagnificationEnabled = value(.isMagnificationEnabled, fallback.isMagnificationEnabled)
        magnificationScale = value(.magnificationScale, fallback.magnificationScale)

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
