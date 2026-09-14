import SwiftUI

/// A keyboard shortcut drawn as a key: inset, hairlined, dim. The treatment
/// Raycast uses everywhere a shortcut is shown.
struct Keycap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.Ink.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Theme.Surface.groupControl, in: .rect(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Theme.Line.hairline, lineWidth: 1)
            }
    }
}
