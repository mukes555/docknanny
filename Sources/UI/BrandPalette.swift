import SwiftUI

/// The accent colour of the app's own surfaces: Settings, the tray, the
/// setup window.
///
/// Lime is the brand and the default; the app icon is always lime. The rest
/// are the sunny family the brand was chosen from, kept as a personal
/// accent choice the way macOS offers one, each shown on the icon so the
/// cards read as colours rather than swatches.
enum BrandPalette: String, Codable, CaseIterable, Identifiable, Sendable {
    case lime
    case tangerine
    case coral
    case sunflower
    case kiwi
    case mint
    case sky
    case lavender
    case watermelon
    case peach
    case candy

    var id: String { rawValue }

    /// Read by ``Theme`` for every accent. Set on the main actor whenever
    /// settings change; declared unsafe only because Theme's statics are
    /// not actor-isolated.
    nonisolated(unsafe) static var current: BrandPalette = .lime

    var localizedName: String {
        switch self {
        case .lime: "Lime"
        case .tangerine: "Tangerine"
        case .coral: "Coral"
        case .sunflower: "Sunflower"
        case .kiwi: "Kiwi"
        case .mint: "Mint"
        case .sky: "Sky"
        case .lavender: "Lavender"
        case .watermelon: "Watermelon"
        case .peach: "Peach"
        case .candy: "Candy"
        }
    }

    var tagline: String {
        switch self {
        case .lime: "The brand"
        case .tangerine: "Warm orange, energetic"
        case .coral: "Red-orange, confident"
        case .sunflower: "Bright yellow, sunny"
        case .kiwi: "Fresh green, the quokka's home"
        case .mint: "Cool green, clean"
        case .sky: "Clear blue, friendly"
        case .lavender: "Soft purple, playful"
        case .watermelon: "Pink-red, bold"
        case .peach: "Soft orange, gentle"
        case .candy: "Pink, sweet"
        }
    }

    /// UI accent, on the dark settings surfaces.
    var accent: Color { Color(hex: accentHex) }
    var accentMuted: Color { Color(hex: accentMutedHex) }
    /// The icon's ground, top-left to bottom-right.
    var groundTop: Color { Color(hex: groundTopHex) }
    var groundBottom: Color { Color(hex: groundBottomHex) }
    /// The glyph on that ground, and the fill inside the drawn screens.
    var glyph: Color { .white }
    var screen: Color { Color(hex: screenHex) }

    var accentHex: UInt32 {
        switch self {
        case .lime: 0xC0DD71
        case .tangerine: 0xF5A05A
        case .coral: 0xF58A7C
        case .sunflower: 0xF2CB57
        case .kiwi: 0xA9D468
        case .mint: 0x74D6AE
        case .sky: 0x7CC0F5
        case .lavender: 0xBFA6F5
        case .watermelon: 0xF58BAA
        case .peach: 0xF7B98F
        case .candy: 0xF4A5C9
        }
    }

    var accentMutedHex: UInt32 {
        switch self {
        case .lime: 0x98B255
        case .tangerine: 0xC97D3F
        case .coral: 0xC46A5E
        case .sunflower: 0xC4A23E
        case .kiwi: 0x83A94C
        case .mint: 0x55AB88
        case .sky: 0x5C99C9
        case .lavender: 0x9583C6
        case .watermelon: 0xC66B87
        case .peach: 0xC8916E
        case .candy: 0xC3809F
        }
    }

    var groundTopHex: UInt32 {
        switch self {
        case .lime: 0xC0DD71
        case .tangerine: 0xF9A24C
        case .coral: 0xF77E6C
        case .sunflower: 0xF7CF4E
        case .kiwi: 0xB6DB61
        case .mint: 0x6BD6A8
        case .sky: 0x6FBCF2
        case .lavender: 0xB69AF2
        case .watermelon: 0xF57A9C
        case .peach: 0xF9BE95
        case .candy: 0xF5A3C8
        }
    }

    var groundBottomHex: UInt32 {
        switch self {
        case .lime: 0x9CC23E
        case .tangerine: 0xE8702A
        case .coral: 0xDF5347
        case .sunflower: 0xEBAA25
        case .kiwi: 0x84B93A
        case .mint: 0x3BB283
        case .sky: 0x3A8BD6
        case .lavender: 0x8B68DE
        case .watermelon: 0xDB4A72
        case .peach: 0xEE8F62
        case .candy: 0xE0709F
        }
    }

    /// A deeper cut of the same hue, so the screens read as screens.
    var screenHex: UInt32 {
        switch self {
        case .lime: 0x74992C
        case .tangerine: 0xB4521A
        case .coral: 0xAE3A31
        case .sunflower: 0xB77E14
        case .kiwi: 0x5F8C25
        case .mint: 0x25855F
        case .sky: 0x2A66A5
        case .lavender: 0x654AAE
        case .watermelon: 0xAB3556
        case .peach: 0xC0673F
        case .candy: 0xB04F7A
        }
    }
}

/// The app icon's glyph drawn in a palette, at any size: the same geometry
/// as tools/make-icon.swift, in a 1024-point space.
struct BrandIconMark: View {
    let palette: BrandPalette
    let size: CGFloat

    var body: some View {
        let scale = size / 1024
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 229 * scale, style: .continuous)
                .fill(LinearGradient(
                    colors: [palette.groundTop, palette.groundBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            RoundedRectangle(cornerRadius: 229 * scale, style: .continuous)
                .fill(LinearGradient(
                    colors: [.white.opacity(0.26), .white.opacity(0)],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6)
                ))
            display(x: 392, y: 236, barY: 474, barX: 446, scale: scale)
            display(x: 162, y: 372, barY: 610, barX: 216, scale: scale)
            RoundedRectangle(cornerRadius: 17 * scale).fill(palette.glyph)
                .frame(width: 114 * scale, height: 34 * scale).offset(x: 340 * scale, y: 716 * scale)
            RoundedRectangle(cornerRadius: 17 * scale).fill(palette.glyph.opacity(0.75))
                .frame(width: 282 * scale, height: 34 * scale).offset(x: 256 * scale, y: 756 * scale)
        }
        .frame(width: size, height: size)
    }

    private func display(x: CGFloat, y: CGFloat, barY: CGFloat, barX: CGFloat, scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 54 * scale, style: .continuous)
                .fill(palette.screen)
                .overlay(RoundedRectangle(cornerRadius: 54 * scale, style: .continuous)
                    .strokeBorder(palette.glyph, lineWidth: max(34 * scale, 1.5)))
                .frame(width: 470 * scale, height: 330 * scale)
                .offset(x: x * scale, y: y * scale)
            RoundedRectangle(cornerRadius: 26 * scale).fill(palette.glyph)
                .frame(width: 362 * scale, height: 52 * scale).offset(x: barX * scale, y: barY * scale)
        }
    }
}

/// One card per palette: the icon in that palette, its name, and a ring on
/// the chosen one. Choosing applies it to the whole app at once.
struct BrandPalettePicker: View {
    @Binding var selection: BrandPalette

    private let columns = Array(repeating: GridItem(.fixed(96), spacing: 12), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Accent colour").settingsText(Theme.Text.row, Theme.Ink.primary)
                Text("The colour of switches, selections and highlights in DockNanny's own windows.")
                    .settingsText(Theme.Text.caption, Theme.Ink.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(BrandPalette.allCases) { palette in
                    card(palette)
                }
            }
        }
        .padding(.horizontal, Theme.Metric.rowPadding)
        .padding(.vertical, 14)
    }

    private func card(_ palette: BrandPalette) -> some View {
        let isSelected = palette == selection
        return Button { selection = palette } label: {
            VStack(spacing: 8) {
                BrandIconMark(palette: palette, size: 56)
                Text(palette.localizedName).settingsText(Theme.Text.caption, Theme.Ink.primary)
            }
            .padding(10)
            .frame(width: 96)
            .background(Theme.Surface.groupControl, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? palette.accent : Theme.Line.hairline, lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(palette.tagline)
        .accessibilityLabel("\(palette.localizedName), \(palette.tagline)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
