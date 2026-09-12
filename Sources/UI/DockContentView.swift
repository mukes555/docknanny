import SwiftUI

/// The contents of one dock: a row or column of tiles on a slab.
///
/// The slab is pinned to the anchored edge and the panel is taller than the
/// slab, so magnified tiles grow into empty space rather than being clipped.
/// Pointer position is tracked here because magnification depends on each
/// tile's distance from the cursor, which only the container can know.
struct DockContentView: View {
    let items: [DockItem]
    let configuration: ResolvedDockConfiguration
    let onActivate: (DockItem) -> Void

    @State private var pointerAxisPosition: CGFloat?

    private var slabSize: CGSize {
        DockMetrics.slabSize(itemCount: items.count, configuration: configuration)
    }

    var body: some View {
        ZStack(alignment: anchorAlignment) {
            DockChrome(
                style: configuration.chromeStyle,
                cornerRadius: DockMetrics.cornerRadius(for: configuration),
                opacity: configuration.chromeOpacity
            )
            .frame(width: slabSize.width, height: slabSize.height)

            tiles
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: anchorAlignment)
    }

    /// The slab hugs the screen edge; the headroom sits on the other side.
    private var anchorAlignment: Alignment {
        switch configuration.edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    private var tiles: some View {
        stack
            .frame(width: slabSize.width, height: slabSize.height)
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    pointerAxisPosition = configuration.edge.isVertical ? location.y : location.x
                case .ended:
                    pointerAxisPosition = nil
                }
            }
    }

    @ViewBuilder
    private var stack: some View {
        if configuration.edge.isVertical {
            VStack(spacing: configuration.itemSpacing) { tileViews }
        } else {
            HStack(spacing: configuration.itemSpacing) { tileViews }
        }
    }

    private var tileViews: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            DockItemView(
                item: item,
                iconSize: configuration.iconSize,
                edge: configuration.edge,
                indicatorStyle: configuration.indicatorStyle,
                scale: scale(forTileAt: index),
                onActivate: { onActivate(item) }
            )
        }
    }

    /// Distance from the slab's leading edge to the centre of tile `index`,
    /// measured along whichever axis the dock runs.
    private func centre(ofTileAt index: Int) -> CGFloat {
        let padding = configuration.itemSpacing
        let stride = configuration.iconSize + configuration.itemSpacing
        return padding + configuration.iconSize / 2 + CGFloat(index) * stride
    }

    private func scale(forTileAt index: Int) -> CGFloat {
        guard let pointerAxisPosition else { return 1 }
        let distance = abs(pointerAxisPosition - centre(ofTileAt: index))

        guard configuration.isMagnificationEnabled else {
            let isUnderPointer = distance <= configuration.iconSize / 2
            return isUnderPointer ? configuration.hoverScale : 1
        }

        return Magnification.scale(
            distance: distance,
            influenceRadius: configuration.iconSize * 2.5,
            maximumScale: configuration.magnificationScale
        )
    }
}
