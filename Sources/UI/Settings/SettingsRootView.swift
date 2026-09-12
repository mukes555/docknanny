import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case layout
    case appearance
    case behavior
    case displays
    case apps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .layout: "Layout"
        case .appearance: "Appearance"
        case .behavior: "Behavior"
        case .displays: "Displays"
        case .apps: "Apps"
        }
    }

    var symbol: String {
        switch self {
        case .layout: "rectangle.3.offgrid"
        case .appearance: "paintbrush"
        case .behavior: "switch.2"
        case .displays: "display.2"
        case .apps: "square.grid.2x2"
        }
    }
}

struct SettingsRootView: View {
    @Bindable var store: SettingsStore
    let displays: DisplayRegistry
    var initialSection: SettingsSection = .layout

    @State private var selection: SettingsSection = .layout

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $selection)
            Rectangle()
                .fill(Theme.Line.hairline)
                .frame(height: 1)
            detail
        }
        .background(Theme.Surface.canvas)
        .frame(minWidth: 660, minHeight: 540)
        // The dock's own chrome is dark, and this palette is built on a
        // near-black canvas where elevation comes from hairlines. Rendering it
        // in light mode would not be the same design with different colours, it
        // would be a different design.
        .preferredColorScheme(.dark)
        .onAppear { selection = initialSection }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .layout: LayoutSettingsView(store: store)
        case .appearance: AppearanceSettingsView(store: store)
        case .behavior: BehaviorSettingsView(store: store)
        case .displays: DisplaysSettingsView(store: store, displays: displays)
        case .apps: AppsSettingsView(store: store)
        }
    }
}

/// The band across the top.
///
/// Centred, with the window's traffic lights floating over the same band on the
/// left, which is why the row is 46pt tall rather than the 34pt its content
/// needs.
struct SettingsTabBar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        HStack(spacing: 3) {
            ForEach(SettingsSection.allCases) { section in
                SettingsTab(
                    section: section,
                    isSelected: selection == section,
                    action: { selection = section }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(Theme.Surface.canvas)
    }
}

private struct SettingsTab: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13, weight: .medium))
                Text(section.title)
                    .settingsText(Theme.Text.tab, isSelected ? Theme.Ink.primary : Theme.Ink.secondary)
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.Ink.secondary)
            .frame(width: 74, height: 40)
            .background(background)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.Surface.selected)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Theme.Line.hairline, lineWidth: 1)
                }
        } else if isHovered {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.Surface.raised)
        }
    }
}
