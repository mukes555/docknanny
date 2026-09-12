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

    @State private var selection: SettingsSection?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(178)
        } detail: {
            detail
                .navigationTitle(selection?.title ?? "Settings")
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear { selection = selection ?? initialSection }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .layout {
        case .layout: LayoutSettingsView(store: store)
        case .appearance: AppearanceSettingsView(store: store)
        case .behavior: BehaviorSettingsView(store: store)
        case .displays: DisplaysSettingsView(store: store, displays: displays)
        case .apps: AppsSettingsView(store: store)
        }
    }
}
