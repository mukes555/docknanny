import Foundation
import Testing

@testable import DockNanny

@Suite("Settings decoding")
struct SettingsDecodingTests {
    private func decode(_ json: String) throws -> Settings {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(Settings.self, from: data)
    }

    @Test("A settings file written by an older version still loads")
    func olderSchemaSurvives() throws {
        // Exactly what Phase 1 persisted, before magnification, chrome styles
        // and alignment existed.
        let legacy = """
        {
          "edge": "bottom",
          "iconSize": 64,
          "itemSpacing": 6,
          "margin": 8,
          "perDisplay": {},
          "pinnedBundleIdentifiers": ["com.apple.finder", "com.example.thing"],
          "skipSystemDockDisplay": false,
          "showRunningApps": true
        }
        """

        let settings = try decode(legacy)

        // Values that were present survive.
        #expect(settings.iconSize == 64)
        #expect(settings.skipSystemDockDisplay == false)
        #expect(settings.pinnedBundleIdentifiers == ["com.apple.finder", "com.example.thing"])

        // Values that did not exist yet take their defaults.
        #expect(settings.alignment == .center)
        #expect(settings.chromeStyle == .glass)
        #expect(settings.isMagnificationEnabled == false)
    }

    @Test("An empty object decodes to defaults rather than throwing")
    func emptyObjectIsDefaults() throws {
        let settings = try decode("{}")
        #expect(settings == Settings())
    }

    @Test("An unknown enum value falls back instead of failing the whole file")
    func unknownEnumDoesNotDiscardEverything() throws {
        let json = """
        {"edge": "diagonal", "iconSize": 72}
        """

        let settings = try decode(json)

        #expect(settings.edge == .bottom)
        #expect(settings.iconSize == 72)
    }

    @Test("A round trip preserves every field")
    func roundTripIsLossless() throws {
        var original = Settings()
        original.edge = .left
        original.alignment = .end
        original.isMagnificationEnabled = true
        original.magnificationScale = 1.85
        original.chromeStyle = .solid
        original.setOverride(DisplayOverride(isEnabled: false, edge: .right), forDisplay: 7)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)

        #expect(decoded == original)
    }

    @Test("A malformed field costs that field, not the display's whole override")
    func oneBadFieldKeepsTheRestOfTheOverride() throws {
        let json = """
        {
          "perDisplay": {
            "1": { "edge": "left" },
            "2": { "edge": 12345, "iconSize": 72 },
            "3": { "tint": "no-such-tint" },
            "4": "not an object"
          }
        }
        """

        let settings = try decode(json)

        #expect(settings.perDisplay["1"]?.edge == .left)
        #expect(settings.perDisplay["2"]?.iconSize == 72)
        #expect(settings.perDisplay["2"]?.edge == nil)
        // Nothing readable was left of displays 3 and 4, so they have no override.
        #expect(settings.perDisplay.count == 2)
    }

    @Test("A wrong-typed entry costs that entry, not the list")
    func oneBadListEntryKeepsTheOthers() throws {
        let settings = try decode("""
        {"pinnedBundleIdentifiers": ["com.apple.Safari", 5, "com.apple.Mail"], "hiddenBundleIdentifiers": "not a list"}
        """)

        #expect(settings.pinnedBundleIdentifiers == ["com.apple.Safari", "com.apple.Mail"])
        #expect(settings.hiddenBundleIdentifiers == Settings().hiddenBundleIdentifiers)
    }

    @Test("Absurd numbers are clamped as they are read, and their readouts cannot trap")
    func numbersAreClampedOnDecode() throws {
        let settings = try decode("""
        {"margin": 1e300, "iconSize": -5, "itemSpacing": 1e19, "magnificationScale": 99, "autoHideDelay": 1e300,
         "perDisplay": {"1": {"iconSize": 1e300}}}
        """)

        #expect(settings.margin == Settings.Limits.margin.upperBound)
        #expect(settings.iconSize == Settings.Limits.iconSize.lowerBound)
        #expect(settings.itemSpacing == Settings.Limits.itemSpacing.upperBound)
        #expect(settings.magnificationScale == Settings.Limits.scale.upperBound)
        #expect(settings.autoHideDelay == Settings.Limits.revealDelay.upperBound)
        #expect(settings.perDisplay["1"]?.iconSize == Settings.Limits.iconSize.upperBound)
        #expect((1e300).wholeNumberLabel == "1000000")
        #expect(Double.nan.wholeNumberLabel == "0")
    }

    @Test("A wholly unreadable perDisplay value falls back without losing the rest of the file")
    func unreadablePerDisplayKeepsOtherSettings() throws {
        let settings = try decode("""
        {"iconSize": 80, "perDisplay": "not an object"}
        """)

        #expect(settings.iconSize == 80)
        #expect(settings.perDisplay.isEmpty)
    }
}
