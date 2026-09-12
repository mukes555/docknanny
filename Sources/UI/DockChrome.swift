import SwiftUI

/// The slab behind the tiles.
///
/// macOS 26 draws Liquid Glass natively. The other two styles exist because
/// glass is not to everyone's taste over a busy wallpaper, and because a solid
/// slab reads better on a low-contrast desktop.
struct DockChrome: View {
    let style: ChromeStyle
    let cornerRadius: CGFloat
    let opacity: Double

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        slab
            .opacity(opacity)
            .overlay {
                shape.strokeBorder(.white.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
    }

    @ViewBuilder
    private var slab: some View {
        switch style {
        case .glass:
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: shape)
            } else {
                shape.fill(.ultraThinMaterial)
            }
        case .translucent:
            shape.fill(.regularMaterial)
        case .solid:
            shape.fill(.background)
        }
    }
}
