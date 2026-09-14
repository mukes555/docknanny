import SwiftUI

/// A colour wash over a dock's slab.
///
/// This is wayfinding, not decoration. With a dock on every screen, a glance at
/// the colour tells you which one you are pointing at, which matters most
/// precisely when the screens are identical models side by side.
///
/// A curated set rather than an arbitrary colour well: every entry is picked to
/// sit under translucent chrome without muddying the icons on top, which an
/// arbitrary picker cannot promise.
enum DockTint: String, Codable, CaseIterable, Sendable, Identifiable {
    case none
    case lime
    case teal
    case blue
    case violet
    case magenta
    case ember
    case sand
    case graphite

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .none: "None"
        case .lime: "Lime"
        case .teal: "Teal"
        case .blue: "Blue"
        case .violet: "Violet"
        case .magenta: "Magenta"
        case .ember: "Ember"
        case .sand: "Sand"
        case .graphite: "Graphite"
        }
    }

    var color: Color? {
        switch self {
        case .none: nil
        case .lime: Color(hex: 0x8BC53F)
        case .teal: Color(hex: 0x2FB8A8)
        case .blue: Color(hex: 0x3E8FE0)
        case .violet: Color(hex: 0x8A6FE8)
        case .magenta: Color(hex: 0xD2519C)
        case .ember: Color(hex: 0xE2703A)
        case .sand: Color(hex: 0xC9A227)
        case .graphite: Color(hex: 0x8A8F98)
        }
    }

    /// Kept low: the slab sits under app icons, and a strong wash turns a dock
    /// into a colour bar with icons on it rather than a tinted dock.
    static let opacity: Double = 0.22
}
