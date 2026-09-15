import Carbon.HIToolbox
import Testing

@testable import DockNanny

@Suite("Hot keys")
struct HotkeyTests {
    @Test("Tile numbers map to the number row in order, and D toggles hiding")
    func keyCodesFollowTheNumberRow() {
        #expect(HotkeyRole.tile(number: 1).keyCode == UInt32(kVK_ANSI_1))
        #expect(HotkeyRole.tile(number: 5).keyCode == UInt32(kVK_ANSI_5))
        #expect(HotkeyRole.tile(number: 9).keyCode == UInt32(kVK_ANSI_9))
        #expect(HotkeyRole.toggleHiding.keyCode == UInt32(kVK_ANSI_D))
    }

    @Test("Every modifier set includes Option, so the shortcuts never collide with Command-number in the app in front")
    func modifierSetsAlwaysIncludeOption() {
        for modifiers in HotkeyModifiers.allCases {
            #expect(modifiers.carbonFlags & UInt32(optionKey) != 0)
        }
        #expect(HotkeyModifiers.controlOption.carbonFlags == UInt32(controlKey | optionKey))
    }

    @Test("Shortcuts are on by default with Control-Option, and a file without the keys gets them")
    func defaultsAreDecoded() throws {
        let decoded = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
        #expect(decoded.tileHotkeysEnabled)
        #expect(decoded.hidingHotkeyEnabled)
        #expect(decoded.hotkeyModifiers == .controlOption)
    }
}
