import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// macdock's settings design language.
///
/// Near-black canvas, elevation carried by hairlines and inset highlights
/// rather than by shadows, uniform dense rows, and a single accent used
/// sparingly. Shadows on a dark surface read as smudges; a one-pixel border at
/// 7% white reads as an edge, which is why every container here is bordered
/// rather than filled with a lighter grey.
enum Theme {
    enum Surface {
        static let canvas = Color(hex: 0x0A0B0D)
        static let raised = Color(hex: 0x121316)
        static let control = Color(hex: 0x1A1B1F)
        static let selected = Color(hex: 0x222327)
    }

    enum Line {
        static let hairline = Color.white.opacity(0.07)
        static let strong = Color.white.opacity(0.13)
        /// The bright top edge that makes a raised surface look lit.
        static let highlight = Color.white.opacity(0.06)
    }

    enum Ink {
        static let primary = Color.white.opacity(0.92)
        static let secondary = Color.white.opacity(0.50)
        static let tertiary = Color.white.opacity(0.32)
    }

    /// Marks selection, and nothing else.
    ///
    /// The moment the accent appears on something you cannot click, the palette
    /// stops meaning anything. Measured 9.53:1 against ``Surface/canvas``, which
    /// is comfortably past WCAG's 4.5:1 for body text.
    static let accent = Color(hex: 0x8BC53F)

    /// The same hue with the volume down, for fills large enough that full
    /// accent would shout.
    static let accentMuted = Color(hex: 0x6F9E33)

    /// State, not decoration. Each is only ever paired with a word saying the
    /// same thing, because colour alone fails anyone who cannot separate these
    /// hues.
    enum Status {
        static let success = Color(hex: 0x4ADE80)
        static let warning = Color(hex: 0xF5A524)
        static let danger = Color(hex: 0xF87171)
    }

    enum Text {
        /// Slightly positive tracking. Unusual on dark UI, and the reason the
        /// type reads as open rather than clotted.
        static let tracking: CGFloat = 0.2

        static let row = Font.system(size: 12.5)
        static let rowEmphasis = Font.system(size: 12.5, weight: .medium)
        static let caption = Font.system(size: 11)
        static let section = Font.system(size: 10.5, weight: .semibold)
        static let tab = Font.system(size: 11, weight: .medium)
        static let title = Font.system(size: 13, weight: .semibold)
    }

    enum Metric {
        static let rowHeight: CGFloat = 34
        static let rowPadding: CGFloat = 12
        static let corner: CGFloat = 8
        static let controlWidth: CGFloat = 168
        static let gutter: CGFloat = 18
    }
}

/// A bordered, faintly lit container. The building block of every group.
struct RaisedSurface: ViewModifier {
    var corner: CGFloat = Theme.Metric.corner

    func body(content: Content) -> some View {
        content
            .background(Theme.Surface.raised, in: .rect(cornerRadius: corner))
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.Line.hairline, lineWidth: 1)
            }
    }
}

extension View {
    func raisedSurface(corner: CGFloat = Theme.Metric.corner) -> some View {
        modifier(RaisedSurface(corner: corner))
    }

    func settingsText(_ font: Font, _ ink: Color) -> some View {
        self.font(font)
            .tracking(Theme.Text.tracking)
            .foregroundStyle(ink)
    }
}
