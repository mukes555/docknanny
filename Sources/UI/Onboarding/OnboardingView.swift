import SwiftUI

/// First run, and the place to come back to for the one optional permission.
///
/// The docks need nothing granted, and the window says so. Accessibility is
/// offered, not required: it lists an app's windows in its tile's menu and
/// keeps windows clear of the docks, nothing else. macOS applies a grant to
/// a running process on its own terms, so a relaunch button sits beside it
/// rather than an explanation.
struct OnboardingView: View {
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    @State private var isTrusted = Accessibility.isTrusted

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.Line.hairline).frame(height: 1)
            points
            Rectangle().fill(Theme.Line.hairline).frame(height: 1)
            accessibilityRow
            Rectangle().fill(Theme.Line.hairline).frame(height: 1)
            footer
        }
        .frame(width: 480)
        .background(Theme.Surface.canvas)
        .preferredColorScheme(.dark)
        .task { await watchAccessibility() }
    }

    /// The grant lands in System Settings, behind this window. Checking back
    /// each second while the view is up means the status flips without a
    /// relaunch when macOS applies it live, which it usually does.
    private func watchAccessibility() async {
        while !Task.isCancelled {
            isTrusted = Accessibility.isTrusted
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(nsImage: Brand.appIcon)
                .resizable()
                .frame(width: 68, height: 68)

            Text("DockNanny is running")
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
                title: "Nothing to grant for the docks",
                detail: "Launching, switching, hiding and quitting apps need no permission at all."
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
                detail: "Settings, and the way out, live under the DockNanny icon up top."
            )
        }
        .padding(20)
    }

    /// Optional, and says exactly what it buys.
    private var accessibilityRow: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: isTrusted ? "checkmark.circle.fill" : "macwindow.on.rectangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isTrusted ? Theme.Status.success : Theme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(isTrusted ? "Accessibility is on" : "Optional: list windows in tile menus")
                    .settingsText(Theme.Text.rowEmphasis, Theme.Ink.primary)
                Text(isTrusted
                    ? "Right-click a running app's tile to see and switch between its windows."
                    : "Right-clicking a running app's tile can list its windows, like the Dock. "
                        + "That reads other apps' window titles, which is what Accessibility access is for.")
                    .settingsText(Theme.Text.caption, Theme.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !isTrusted {
                    Text(adHocNote ?? "If the tile menus still show no windows after granting, relaunch.")
                        .settingsText(Theme.Text.caption, Theme.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if !isTrusted {
                    Button("Grant...") { Accessibility.request() }
                        .controlSize(.small)
                }
                Button("Relaunch") { AppRestarter.restart() }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityElement(children: .contain)
    }

    /// A build signed the naive way loses the grant on every rebuild while
    /// System Settings keeps showing it as granted. Saying so here beats a
    /// bug report.
    private var adHocNote: String? {
        guard Accessibility.grantIsTiedToThisExactBinary else { return nil }
        return "This build's signature ties the grant to this exact binary, so macOS forgets it after every "
            + "rebuild even though System Settings still lists DockNanny as allowed. Remove DockNanny from that "
            + "list and grant again, and build with tools/dev.sh so it sticks."
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
