import SwiftUI

/// The application name shown beside a hovered tile, in the system Dock's
/// idiom: a dark rounded plate with white text, riding just clear of the icon.
struct TileLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(white: 0.13).opacity(0.94), in: .rect(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 6, y: 2)
            .frame(maxWidth: DockMetrics.labelMaximumWidth)
    }
}
