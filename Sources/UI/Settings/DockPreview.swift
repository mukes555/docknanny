import SwiftUI

/// A live miniature of the dock, rendered with the settings currently on
/// screen.
///
/// It draws the real ``DockContentView`` rather than an approximation, so what
/// the preview shows is what the panel will do. Hit testing is off: this is a
/// mirror, not a second dock.
struct DockPreview: View {
    let settings: Settings
    /// The display to preview for, or the synthetic reference display so
    /// the preview reflects global settings rather than whichever screen the
    /// settings window is on.
    var display: Display?
    var height: CGFloat = 190

    /// Icons come from Launch Services, which is a disk lookup. Resolving them
    /// in the body would repeat that on every frame of a slider drag, so they
    /// are resolved only when the pinned set actually changes.
    @State private var items: [DockItem] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Tall enough that a vertical dock is legible rather than a sliver.
    private var boxInset: CGFloat { min(14, height / 8) }

    /// A synthetic display, so the preview reflects global settings rather than
    /// whichever screen the settings window happens to be on.
    private static let referenceDisplay = Display(
        id: 0,
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1040),
        backingScaleFactor: 2,
        isPrimary: true,
        localizedName: "Preview"
    )

    private var configuration: ResolvedDockConfiguration {
        settings.resolved(for: display ?? Self.referenceDisplay)
    }

    private var fit: DockFit {
        DockMetrics.fit(
            itemCount: items.count,
            configuration: configuration,
            availableLength: .greatestFiniteMagnitude
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: alignment) {
                desktop
                dock(in: geometry.size)
            }
        }
        .frame(height: height)
        .clipShape(.rect(cornerRadius: 10))
        .accessibilityLabel("Preview of the dock with the current settings")
        .onAppear(perform: reload)
        .onChange(of: settings.pinnedBundleIdentifiers) { _, _ in reload() }
        .onChange(of: settings.hiddenBundleIdentifiers) { _, _ in reload() }
        .onChange(of: settings.mirrorSystemDock) { _, _ in reload() }
        .onChange(of: settings.showTrash) { _, _ in reload() }
    }

    /// Stands in for a desktop so translucency and glass have something to sit
    /// against. A flat panel colour would make every chrome style look alike.
    private var desktop: some View {
        LinearGradient(
            colors: [BrandPalette.groundTop, Theme.accent.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func dock(in box: CGSize) -> some View {
        let factor = scale(toFit: box)

        return DockContentView(
            items: items,
            fit: fit,
            configuration: configuration,
            actions: .inert
        )
        .frame(width: fit.panelSize.width, height: fit.panelSize.height)
        .scaleEffect(factor, anchor: .center)
        // scaleEffect is a render-time transform: the view still claims its
        // unscaled size in layout. Without restating the real occupied size the
        // shrunken dock still overflowed the box and was clipped.
        .frame(width: fit.panelSize.width * factor, height: fit.panelSize.height * factor)
        .allowsHitTesting(false)
        .padding(boxInset)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: fit.panelSize)
    }

    private var alignment: Alignment {
        switch configuration.edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    /// Shrinks the real dock until it fits the preview box. Never enlarges: a
    /// magnified miniature would misrepresent the sizes being chosen.
    private func scale(toFit box: CGSize) -> CGFloat {
        let available = CGSize(
            width: max(1, box.width - boxInset * 2),
            height: max(1, box.height - boxInset * 2)
        )
        let widthRatio = available.width / max(fit.panelSize.width, 1)
        let heightRatio = available.height / max(fit.panelSize.height, 1)
        return min(1, min(widthRatio, heightRatio))
    }

    /// The preview shows what the dock shows, mirrored or custom.
    private var pinnedSource: [String] {
        settings.mirrorSystemDock ? SystemDockMonitor.read().pinsWithFinder : configuration.pinnedBundleIdentifiers
    }

    private func reload() {
        let source = DockSource(
            pinned: Array(pinnedSource.prefix(8)),
            showsTrash: configuration.showTrash
        )
        items = DockContents.items(source: source, configuration: configuration, iconProvider: DockContents.icon(for:))
    }
}
