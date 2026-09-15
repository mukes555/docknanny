import Carbon.HIToolbox

/// Which modifier keys the global shortcuts are held with.
///
/// Control-Option is the default because nothing in macOS, and very little
/// else, uses it with the number row. Option alone would type ¡™£ in every
/// app, and Command-number belongs to the app in front.
enum HotkeyModifiers: String, Codable, CaseIterable, Sendable {
    case controlOption
    case optionCommand
    case controlOptionCommand

    var localizedName: String {
        switch self {
        case .controlOption: "⌃⌥"
        case .optionCommand: "⌥⌘"
        case .controlOptionCommand: "⌃⌥⌘"
        }
    }

    /// Carbon's modifier bits.
    var carbonFlags: UInt32 {
        switch self {
        case .controlOption: UInt32(controlKey | optionKey)
        case .optionCommand: UInt32(optionKey | cmdKey)
        case .controlOptionCommand: UInt32(controlKey | optionKey | cmdKey)
        }
    }
}

/// The keys DockNanny binds, by what they do rather than by key code.
enum HotkeyRole: Hashable, Sendable {
    /// Opens the tile at this position (1 to 9) on the dock under the pointer.
    case tile(number: Int)
    /// The system Dock's Option-Command-D, for these docks.
    case toggleHiding

    static let tileNumbers = 1...9

    /// Virtual key codes are layout-independent for the number row on every
    /// ANSI, ISO and JIS keyboard, so "3" is the same physical key everywhere.
    var keyCode: UInt32 {
        switch self {
        case .tile(let number):
            let row: [Int] = [
                kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9
            ]
            return UInt32(row[number - 1])
        case .toggleHiding:
            return UInt32(kVK_ANSI_D)
        }
    }

    /// What the settings pane prints beside the description.
    var keyLabel: String {
        switch self {
        case .tile(let number): "\(number)"
        case .toggleHiding: "D"
        }
    }
}
