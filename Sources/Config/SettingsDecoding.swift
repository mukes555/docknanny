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
    /// independently and falls back to its default. Numbers are clamped
    /// here, not only where they are used: the settings window formats the
    /// stored value, and a stored 1e300 would take the app down with it.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()
        let reader = TolerantReader(container: container)

        edge = reader.value(.edge, fallback.edge)
        alignment = reader.value(.alignment, fallback.alignment)
        margin = reader.value(.margin, fallback.margin).clamped(to: Limits.margin)

        brandPalette = reader.value(.brandPalette, fallback.brandPalette)
        iconSize = reader.value(.iconSize, fallback.iconSize).clamped(to: Limits.iconSize)
        itemSpacing = reader.value(.itemSpacing, fallback.itemSpacing).clamped(to: Limits.itemSpacing)
        chromeStyle = reader.value(.chromeStyle, fallback.chromeStyle)
        indicatorStyle = reader.value(.indicatorStyle, fallback.indicatorStyle)
        tint = reader.value(.tint, fallback.tint)

        isMagnificationEnabled = reader.value(.isMagnificationEnabled, fallback.isMagnificationEnabled)
        magnificationScale = reader.value(.magnificationScale, fallback.magnificationScale).clamped(to: Limits.scale)

        showRunningApps = reader.value(.showRunningApps, fallback.showRunningApps)
        skipSystemDockDisplay = reader.value(.skipSystemDockDisplay, fallback.skipSystemDockDisplay)
        autoHide = reader.value(.autoHide, fallback.autoHide)
        autoHideDelay = reader.value(.autoHideDelay, fallback.autoHideDelay).clamped(to: Limits.revealDelay)
        activeClickBehavior = reader.value(.activeClickBehavior, fallback.activeClickBehavior)
        opensAppsOnClickedScreen = reader.value(.opensAppsOnClickedScreen, fallback.opensAppsOnClickedScreen)
        keepWindowsClear = reader.value(.keepWindowsClear, fallback.keepWindowsClear)
        launchAtLogin = reader.value(.launchAtLogin, fallback.launchAtLogin)
        hasSeenWelcome = reader.value(.hasSeenWelcome, fallback.hasSeenWelcome)

        tileHotkeysEnabled = reader.value(.tileHotkeysEnabled, fallback.tileHotkeysEnabled)
        hidingHotkeyEnabled = reader.value(.hidingHotkeyEnabled, fallback.hidingHotkeyEnabled)
        hotkeyModifiers = reader.value(.hotkeyModifiers, fallback.hotkeyModifiers)

        mirrorSystemDock = reader.value(.mirrorSystemDock, fallback.mirrorSystemDock)
        pinnedBundleIdentifiers = reader.strings(.pinnedBundleIdentifiers) ?? fallback.pinnedBundleIdentifiers
        pinnedOthers = reader.strings(.pinnedOthers) ?? fallback.pinnedOthers
        hiddenBundleIdentifiers = reader.strings(.hiddenBundleIdentifiers) ?? fallback.hiddenBundleIdentifiers
        showTrash = reader.value(.showTrash, fallback.showTrash)

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
        // An override with nothing readable left in it is no override.
        return entries.compactMapValues(\.value).filter { !$0.value.isDefault }
    }
}

extension DisplayOverride {
    /// Field by field, like ``Settings``: a value a newer DockNanny wrote (a
    /// tint this build does not know) costs that field, not the display's
    /// whole setup, which the next save would otherwise drop for good.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let reader = TolerantReader(container: container)

        isEnabled = reader.optional(.isEnabled)
        edge = reader.optional(.edge)
        alignment = reader.optional(.alignment)
        iconSize = (reader.optional(.iconSize) as Double?)?.clamped(to: Settings.Limits.iconSize)
        showRunningApps = reader.optional(.showRunningApps)
        autoHide = reader.optional(.autoHide)
        tint = reader.optional(.tint)
        pinnedBundleIdentifiers = reader.strings(.pinnedBundleIdentifiers)
        allowedBundleIdentifiers = reader.strings(.allowedBundleIdentifiers)
    }
}

/// Reads one key at a time, falling back per key and saying so in the log,
/// so a stray value costs that one setting rather than the whole file.
private struct TolerantReader<Key: CodingKey> {
    let container: KeyedDecodingContainer<Key>

    func value<Value: Decodable>(_ key: Key, _ fallback: Value) -> Value {
        optional(key) ?? fallback
    }

    /// nil when the key is absent or unreadable.
    func optional<Value: Decodable>(_ key: Key) -> Value? {
        do {
            return try container.decodeIfPresent(Value.self, forKey: key)
        } catch {
            Log.settings.error("Setting \(key.stringValue, privacy: .public) is unreadable; using its default")
            return nil
        }
    }

    /// Entry by entry: one entry of the wrong type costs that entry, not the
    /// list, which the next save would otherwise write out shortened.
    func strings(_ key: Key) -> [String]? {
        guard let entries: [FailableString] = optional(key) else { return nil }
        if entries.contains(where: { $0.value == nil }) {
            Log.settings.error("Setting \(key.stringValue, privacy: .public) has entries that are not text; skipped")
        }
        return entries.compactMap(\.value)
    }
}

private struct FailableString: Decodable {
    let value: String?

    init(from decoder: any Decoder) throws {
        value = try? decoder.singleValueContainer().decode(String.self)
    }
}

/// Decodes a display override, yielding nil instead of throwing when the entry
/// is not even an object. Without this a single bad entry aborts the whole
/// dictionary.
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

    /// The whole number a readout shows for a setting. `Int(Double)` traps
    /// past `Int.max`, and a value can come from a file or the Dock's own
    /// preferences, so the conversion is bounded first.
    var wholeNumberLabel: String {
        "\(Int(clamped(to: 0...1_000_000)))"
    }
}
