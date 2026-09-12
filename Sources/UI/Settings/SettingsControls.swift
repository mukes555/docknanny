import SwiftUI

/// An enum that can be offered as a labelled choice in settings.
protocol SettingsOption: CaseIterable, Hashable, Identifiable {
    var localizedName: String { get }
}

extension DockEdge: SettingsOption { var id: String { rawValue } }
extension DockAlignment: SettingsOption { var id: String { rawValue } }
extension ChromeStyle: SettingsOption { var id: String { rawValue } }
extension IndicatorStyle: SettingsOption { var id: String { rawValue } }
extension ActiveClickBehavior: SettingsOption { var id: String { rawValue } }

/// One row: label and optional explanation on the left, control on the right,
/// at a fixed height so a column of them reads as a ruled list rather than a
/// stack of differently sized cards.
struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .settingsText(Theme.Text.row, Theme.Ink.primary)
                if let subtitle {
                    Text(subtitle)
                        .settingsText(Theme.Text.caption, Theme.Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 10)

            control()
                .frame(width: Theme.Metric.controlWidth, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Metric.rowPadding)
        .frame(minHeight: subtitle == nil ? Theme.Metric.rowHeight : Theme.Metric.rowHeight + 12)
    }
}

/// The rule between rows. Inset from the left so it reads as a list separator
/// rather than a box edge.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Line.hairline)
            .frame(height: 1)
            .padding(.leading, Theme.Metric.rowPadding)
    }
}

struct SettingsToggle: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(title)
                .accessibilityHint(subtitle ?? "")
        }
    }
}

struct SettingsPicker<Option: SettingsOption>: View where Option.AllCases: RandomAccessCollection {
    let title: String
    var subtitle: String?
    @Binding var selection: Option

    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            Picker("", selection: $selection) {
                ForEach(Option.allCases) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .accessibilityLabel(title)
            .accessibilityValue(selection.localizedName)
        }
    }
}

struct SettingsOptionalPicker<Option: SettingsOption>: View
where Option.AllCases: RandomAccessCollection {
    let title: String
    var subtitle: String?
    @Binding var selection: Option?
    let inheritedName: String

    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            Picker("", selection: $selection) {
                Text("Global (\(inheritedName))").tag(Option?.none)
                Divider()
                ForEach(Option.allCases) { option in
                    Text(option.localizedName).tag(Option?.some(option))
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .accessibilityLabel(title)
            .accessibilityValue(selection?.localizedName ?? "global")
        }
    }
}

struct SettingsSlider: View {
    let title: String
    var subtitle: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var format: (Double) -> String = { "\(Int($0))" }

    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            HStack(spacing: 10) {
                Slider(value: $value, in: range, step: step)
                    .controlSize(.mini)
                    .tint(Theme.accent)
                    .accessibilityLabel(title)
                    .accessibilityValue(format(value))
                ValueChip(text: format(value))
            }
        }
    }
}

/// The numeric readout beside a slider, given the inset treatment that makes it
/// read as a value rather than as a label.
struct ValueChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.Ink.secondary)
            .frame(minWidth: 42)
            .padding(.vertical, 3)
            .background(Theme.Surface.control, in: .rect(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Theme.Line.hairline, lineWidth: 1)
            }
    }
}

/// A titled group of rows.
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .settingsText(Theme.Text.section, Theme.Ink.tertiary)
                .padding(.leading, 2)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                content()
            }
            .raisedSurface()
        }
    }
}

/// The scrolling body shared by every pane.
struct SettingsPane<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metric.gutter) {
                content()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Surface.canvas)
    }
}
