import SwiftUI

/// The contents of one dock: a row or column of application tiles on a
/// translucent slab.
struct DockContentView: View {
    let items: [DockItem]
    let configuration: ResolvedDockConfiguration
    let onActivate: (DockItem) -> Void

    var body: some View {
        tiles
            .padding(configuration.itemSpacing)
            .modifier(DockChrome(cornerRadius: DockMetrics.cornerRadius(for: configuration)))
    }

    @ViewBuilder
    private var tiles: some View {
        if configuration.edge.isVertical {
            VStack(spacing: configuration.itemSpacing) { tileList }
        } else {
            HStack(spacing: configuration.itemSpacing) { tileList }
        }
    }

    private var tileList: some View {
        ForEach(items) { item in
            DockItemView(
                item: item,
                iconSize: configuration.iconSize,
                edge: configuration.edge,
                onActivate: { onActivate(item) }
            )
        }
    }
}

/// The dock's translucent backing.
///
/// macOS 26 draws this with the native Liquid Glass material. The material
/// fallback exists so the view still renders if the deployment target is ever
/// lowered, and so the app degrades rather than disappears if the effect is
/// unavailable.
private struct DockChrome: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
        }
    }
}
