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

/// DockNanny's settings design language.
///
/// Near-black canvas, elevation carried by hairlines and inset highlights
/// rather than by shadows, uniform dense rows, and a single accent used
/// sparingly. Shadows on a dark surface read as smudges; a one-pixel border at
/// 7% white reads as an edge, which is why every container here is bordered
/// rather than filled with a lighter grey.
enum Theme {
    enum Surface {
        /// Opaque ground, for the one-off windows that are not vibrant.
        static let canvas = Color(hex: 0x0A0B0D)
        static let raised = Color(hex: 0x121316)
        static let control = Color(hex: 0x1A1B1F)
        static let selected = Color(hex: 0x222327)

        /// The settings window is translucent: the desktop bleeds through a
        /// dark material, the way Raycast's does. Groups and controls are
        /// therefore lifts of white over whatever is behind, not fixed greys,
        /// or they would read as opaque slabs floating on a see-through window.
        static let group = Color.white.opacity(0.045)
        static let groupControl = Color.white.opacity(0.08)
        static let sidebarSelected = Color.white.opacity(0.09)
        static let sidebarHover = Color.white.opacity(0.045)
        /// Deepens the material toward near-black without killing the bleed.
        static let scrim = Color.black.opacity(0.30)
    }

    /// Hairlines are decorative, not informational: a rule between two rows
    /// identifies nothing, the row's own text does, so WCAG's 3:1 for UI
    /// components does not bind them. Raising them to 3:1 would replace the
    /// design with grey boxes. They strengthen under Increase Contrast instead,
    /// which is what that setting is for.
    enum Line {
        static let hairline = Color.white.opacity(0.07)
        static let strong = Color.white.opacity(0.13)

        /// The bright top edge that makes a raised surface look lit.
        static let highlight = Color.white.opacity(0.06)

        /// Edges that carry structure take the Increase Contrast setting, which
        /// is the honest place to make them louder rather than shouting at
        /// everyone by default.
        static func hairline(for contrast: ColorSchemeContrast) -> Color {
            Color.white.opacity(contrast == .increased ? 0.24 : 0.07)
        }
    }

    enum Ink {
        static let primary = Color.white.opacity(0.92)
        static let secondary = Color.white.opacity(0.50)
        /// 46%, not the 32% this started at.
        ///
        /// White at a low alpha over near-black composites far darker than the
        /// alpha suggests, which is the trap in a palette like this. Measured,
        /// 32% gave 2.89:1 against Surface.raised while carrying the section
        /// headers, which are real text needing 4.5:1. 45% is the exact
        /// threshold; 46% buys margin without brightening headers into
        /// competing with the row labels they sit above.
        static let tertiary = Color.white.opacity(0.46)
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

    /// Measured off Raycast's own settings window rather than a description
    /// of it. The first pass here was 12.5pt type on 34pt rows with tiny
    /// uppercase section labels, which is denser and smaller than anything
    /// Raycast ships: its rows are about 45pt, its labels about 15pt, and its
    /// section headers are ordinary Title Case in primary ink.
    enum Text {
        static let tracking: CGFloat = 0.1

        static let row = Font.system(size: 14.5)
        static let rowEmphasis = Font.system(size: 14.5, weight: .medium)
        static let caption = Font.system(size: 12.5)
        static let section = Font.system(size: 16, weight: .medium)
        static let sidebar = Font.system(size: 14, weight: .medium)
        static let title = Font.system(size: 15, weight: .semibold)
    }

    enum Metric {
        static let rowHeight: CGFloat = 46
        static let rowPadding: CGFloat = 16
        static let corner: CGFloat = 12
        static let controlWidth: CGFloat = 210
        static let gutter: CGFloat = 26
        static let sidebarWidth: CGFloat = 214
    }
}

/// A bordered, faintly lit container. The building block of every group.
struct RaisedSurface: ViewModifier {
    var corner: CGFloat = Theme.Metric.corner

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background(Theme.Surface.group, in: .rect(cornerRadius: corner))
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.Line.hairline(for: contrast), lineWidth: 1)
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
