import SwiftUI

/// One display in the tray: a live miniature of its dock, its name, and the
/// three things worth changing without opening Settings.
struct TrayDisplayRow: View {
    @Bindable var store: SettingsStore
    let display: Display
    let onOpen: () -> Void

    private var resolved: ResolvedDockConfiguration {
        store.settings.resolved(for: display)
    }

    var body: some View {
        VStack(spacing: 9) {
            DockPreview(settings: store.settings, display: display, height: 58)

            HStack(spacing: 10) {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(display.localizedName)
                            .settingsText(Theme.Text.rowEmphasis, Theme.Ink.primary)
                        Text(subtitle)
                            .settingsText(Theme.Text.caption, Theme.Ink.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Open display settings")

                Spacer(minLength: 6)

                edgeSwitcher

                Circle()
                    .fill(resolved.tint.color ?? Theme.Surface.groupControl)
                    .frame(width: 10, height: 10)
                    .overlay { Circle().strokeBorder(Theme.Line.strong, lineWidth: 1) }
                    .help("Tint: \(resolved.tint.localizedName)")

                Toggle("", isOn: enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(Theme.accent)
                    .accessibilityLabel("Show a dock on \(display.localizedName)")
            }
        }
        .padding(10)
    }

    private var subtitle: String {
        let size = "\(Int(display.frame.width))×\(Int(display.frame.height))"
        return display.isPrimary ? "\(size) · primary" : size
    }

    private var enabled: Binding<Bool> {
        Binding(
            get: { resolved.isEnabled },
            set: { value in
                var override = store.settings.override(forDisplay: display.id)
                override.isEnabled = value
                store.settings.setOverride(override, forDisplay: display.id)
            }
        )
    }

    /// Bottom, left, right as three glyphs. A dock's edge is the setting
    /// people change per screen most, and the tray is the fastest place.
    private var edgeSwitcher: some View {
        HStack(spacing: 1) {
            ForEach(DockEdge.allCases) { edge in
                Button { setEdge(edge) } label: {
                    Image(systemName: symbol(for: edge))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(resolved.edge == edge ? Theme.Ink.primary : Theme.Ink.tertiary)
                        .frame(width: 24, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(resolved.edge == edge ? Theme.Surface.selected : .clear)
                        )
                }
                .buttonStyle(.plain)
                .help("\(edge.localizedName) edge")
                .accessibilityLabel("\(edge.localizedName) edge")
                .accessibilityAddTraits(resolved.edge == edge ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .background(Theme.Surface.groupControl, in: .rect(cornerRadius: 7))
    }

    private func setEdge(_ edge: DockEdge) {
        var override = store.settings.override(forDisplay: display.id)
        override.edge = edge == store.settings.edge ? nil : edge
        store.settings.setOverride(override, forDisplay: display.id)
    }

    private func symbol(for edge: DockEdge) -> String {
        switch edge {
        case .bottom: "rectangle.bottomthird.inset.filled"
        case .left: "rectangle.leadingthird.inset.filled"
        case .right: "rectangle.trailingthird.inset.filled"
        }
    }
}
