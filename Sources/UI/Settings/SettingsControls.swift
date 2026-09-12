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

/// One labelled row: title and optional explanation on the left, control on
/// the right.
///
/// Every pane is built from these, which is what keeps a pane a short list of
/// declarations instead of a thousand lines of bespoke layout.
struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Read as one phrase. Left alone, VoiceOver announces the title and
            // the explanation as two unrelated items, with the control it
            // describes a third.
            .accessibilityElement(children: .combine)

            Spacer(minLength: 12)

            control()
                .frame(minWidth: 150, maxWidth: 190, alignment: .trailing)
        }
        .padding(.vertical, 5)
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
                .controlSize(.small)
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

struct SettingsSlider: View {
    let title: String
    var subtitle: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var format: (Double) -> String = { "\(Int($0))" }

    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            HStack(spacing: 8) {
                Slider(value: $value, in: range, step: step)
                    .controlSize(.small)
                    .accessibilityLabel(title)
                    .accessibilityValue(format(value))
                Text(format(value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }
}

/// A titled group of rows.
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 9))
        }
    }
}

/// The scrolling body shared by every pane.
struct SettingsPane<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A picker whose nil case means "inherit the global setting".
struct SettingsOptionalPicker<Option: SettingsOption>: View
where Option.AllCases: RandomAccessCollection {
    let title: String
    var subtitle: String?
    @Binding var selection: Option?
    let inheritedName: String

    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            Picker("", selection: $selection) {
                Text("Same as global (\(inheritedName))").tag(Option?.none)
                Divider()
                ForEach(Option.allCases) { option in
                    Text(option.localizedName).tag(Option?.some(option))
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .accessibilityLabel(title)
            .accessibilityValue(selection?.localizedName ?? "same as global")
        }
    }
}
