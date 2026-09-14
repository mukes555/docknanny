import SwiftUI

/// First run.
///
/// This used to be a permission gate asking for Accessibility, which macdock
/// does not use: every dock action goes through NSRunningApplication and
/// NSWorkspace, and neither needs a grant. Asking for the most alarming
/// permission on macOS to power nothing is the same fault that got the Screen
/// Recording request deleted, and the rule written into PermissionsService
/// applies to macdock itself.
///
/// So it says the true thing instead, which happens to be the best thing it
/// could say: nothing to grant, it is already working.
struct OnboardingView: View {
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.Line.hairline).frame(height: 1)
            points
            Rectangle().fill(Theme.Line.hairline).frame(height: 1)
            footer
        }
        .frame(width: 460)
        .background(Theme.Surface.canvas)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 68, height: 68)

            Text("macdock is running")
                .settingsText(.system(size: 19, weight: .semibold), Theme.Ink.primary)

            Text("There is now a dock on every display you have connected.")
                .settingsText(Theme.Text.row, Theme.Ink.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.top, 30)
        .padding(.bottom, 22)
    }

    private var points: some View {
        VStack(spacing: 0) {
            Point(
                symbol: "lock.open",
                title: "No permissions needed",
                detail: "macdock asks for nothing. No Accessibility, no Screen Recording."
            )
            SettingsDivider()
            Point(
                symbol: "cursorarrow.click.2",
                title: "It never takes focus",
                detail: "Clicking a dock icon leaves your keyboard where it was."
            )
            SettingsDivider()
            Point(
                symbol: "menubar.arrow.up.rectangle",
                title: "Everything is in the menu bar",
                detail: "Settings, and the way out, live under the macdock icon up top."
            )
        }
        .padding(20)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Open Settings", action: onOpenSettings)
                .controlSize(.large)
            Spacer()
            Button("Done", action: onDismiss)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }
}

private struct Point: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).settingsText(Theme.Text.rowEmphasis, Theme.Ink.primary)
                Text(detail).settingsText(Theme.Text.caption, Theme.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}
