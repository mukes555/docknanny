import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case layout
    case appearance
    case behavior
    case displays
    case apps
    case presets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .layout: "Layout"
        case .appearance: "Appearance"
        case .behavior: "Behavior"
        case .displays: "Displays"
        case .apps: "Apps"
        case .presets: "Presets"
        }
    }

    var symbol: String {
        switch self {
        case .layout: "rectangle.3.offgrid"
        case .appearance: "paintbrush.fill"
        case .behavior: "switch.2"
        case .displays: "display.2"
        case .apps: "square.grid.2x2.fill"
        case .presets: "wand.and.stars"
        }
    }

    /// Each section gets its own tile colour, which is how a sidebar of
    /// same-weight labels becomes scannable at a glance.
    var tint: Color {
        switch self {
        case .layout: Color(hex: 0x3E8FE0)
        case .appearance: Color(hex: 0x8A6FE8)
        case .behavior: Color(hex: 0xE2703A)
        case .displays: Color(hex: 0x2FB8A8)
        case .apps: Color(hex: 0x8BC53F)
        case .presets: Color(hex: 0xE0559A)
        }
    }
}

/// Sidebar plus content, on a pane of dark glass.
///
/// A sidebar rather than a tab band, because that is what a settings window
/// is on this platform and what Raycast's actually is. An earlier pass here
/// used a top tab band on the strength of a written description of Raycast's
/// design language; the screenshots say otherwise.
struct SettingsRootView: View {
    @Bindable var store: SettingsStore
    let displays: DisplayRegistry
    var initialSection: SettingsSection = .layout

    @State private var selection: SettingsSection = .layout

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.Line.hairline).frame(width: 1)
            content
        }
        .background {
            ZStack {
                VibrantBackground(material: .underWindowBackground)
                Theme.Surface.scrim
            }
        }
        // The window has a full-size content view precisely so the sidebar's
        // material can run up under the traffic lights. SwiftUI still insets
        // for the title bar unless told not to, which left a flat band across
        // the top of an otherwise glass window.
        .ignoresSafeArea()
        .frame(minWidth: 860, minHeight: 660)
        .preferredColorScheme(.dark)
        .onAppear { selection = initialSection }
        .background(tabShortcuts)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
                .padding(.top, 54)
                .padding(.bottom, 18)

            ForEach(SettingsSection.allCases) { section in
                SidebarItem(
                    section: section,
                    isSelected: selection == section,
                    action: { selection = section }
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: Theme.Metric.sidebarWidth)
        .background(VibrantBackground(material: .sidebar))
    }

    private var sidebarHeader: some View {
        HStack(spacing: 11) {
            Image(nsImage: Brand.appIcon)
                .resizable()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("macdock").settingsText(Theme.Text.title, Theme.Ink.primary)
                Text(Self.version).settingsText(Theme.Text.caption, Theme.Ink.secondary)
            }
        }
        .padding(.horizontal, 8)
    }

    private static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "Version \(short ?? "dev")"
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(selection.title)
                .settingsText(Theme.Text.title, Theme.Ink.primary)
                .padding(.horizontal, 30)
                .padding(.top, 58)
                .padding(.bottom, 6)
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Zero-sized buttons exist purely to register key equivalents: SwiftUI has
    /// no way to attach a shortcut to a view that is not a control.
    private var tabShortcuts: some View {
        ForEach(Array(SettingsSection.allCases.enumerated()), id: \.element.id) { index, section in
            Button("") { selection = section }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .hidden()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .layout: LayoutSettingsView(store: store)
        case .appearance: AppearanceSettingsView(store: store)
        case .behavior: BehaviorSettingsView(store: store)
        case .displays: DisplaysSettingsView(store: store, displays: displays)
        case .apps: AppsSettingsView(store: store)
        case .presets: PresetsSettingsView(store: store)
        }
    }
}

private struct SidebarItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                IconTile(symbol: section.symbol, tint: section.tint)
                Text(section.title)
                    .settingsText(Theme.Text.sidebar, isSelected ? Theme.Ink.primary : Theme.Ink.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(background)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.Surface.sidebarSelected)
        } else if isHovered {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.Surface.sidebarHover)
        }
    }
}

/// The coloured rounded square behind a sidebar symbol.
struct IconTile: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
            .fill(tint.gradient)
            .frame(width: 24, height: 24)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}
