import SwiftUI

/// Edge as three little pictures of a screen.
///
/// A choice that is inherently spatial should be shown, not named: Raycast
/// does the same for its Window Mode, with a thumbnail per option. Three
/// diagrams are read faster than the words Bottom, Left and Right, and they
/// rule out the moment of wondering which way "Left" faces.
struct EdgeCardPicker: View {
    let title: String
    var subtitle: String?
    @Binding var selection: DockEdge

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).settingsText(Theme.Text.row, Theme.Ink.primary)
                if let subtitle {
                    Text(subtitle).settingsText(Theme.Text.caption, Theme.Ink.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 14) {
                ForEach(DockEdge.allCases) { edge in
                    EdgeCard(edge: edge, isSelected: edge == selection) { selection = edge }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.Metric.rowPadding)
        .padding(.vertical, 14)
    }
}

private struct EdgeCard: View {
    let edge: DockEdge
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                diagram
                    .frame(width: 118, height: 76)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isHovered && !isSelected ? Theme.Surface.groupControl : Theme.Surface.group)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                isSelected ? Theme.accent : Theme.Line.hairline,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
                Text(edge.localizedName)
                    .settingsText(Theme.Text.caption, isSelected ? Theme.Ink.primary : Theme.Ink.secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(edge.localizedName) edge")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// A screen with a bar on the chosen edge.
    private var diagram: some View {
        ZStack(alignment: barAlignment) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: 78, height: 50)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isSelected ? Theme.accent : Color.white.opacity(0.55))
                .frame(width: barSize.width, height: barSize.height)
                .padding(4)
        }
        .frame(width: 78, height: 50)
    }

    private var barAlignment: Alignment {
        switch edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    private var barSize: CGSize {
        edge.isVertical ? CGSize(width: 5, height: 28) : CGSize(width: 40, height: 5)
    }
}
