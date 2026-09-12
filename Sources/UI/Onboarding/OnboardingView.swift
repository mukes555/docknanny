import SwiftUI

/// First-run setup.
///
/// Permission state is polled while this is on screen, so granting something
/// in System Settings updates the row here without the user coming back to
/// press anything.
struct OnboardingView: View {
    let permissions: PermissionsService
    let onRestart: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            rows
            Divider()
            footer
        }
        .frame(width: 480)
        .onAppear { permissions.startPolling() }
        .onDisappear { permissions.stopPolling() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            // The quokka mark replaces this once branding assets are generated.
            // See docs/BRANDING.md.
            Image(systemName: "menubar.dock.rectangle")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(BrandPalette.lime)

            Text("Welcome to macdock")
                .font(.system(size: 19, weight: .semibold))

            Text("A dock on every display. Two permissions and you are set.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var rows: some View {
        VStack(spacing: 10) {
            ForEach(Permission.allCases) { permission in
                PermissionRow(
                    permission: permission,
                    isGranted: permissions.isGranted(permission),
                    onGrant: { permissions.request(permission) }
                )
            }
        }
        .padding(20)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if !permissions.isSatisfied {
                Label(
                    "Already granted it? macOS only applies Accessibility on the next launch.",
                    systemImage: "info.circle"
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button("Restart macdock", action: onRestart)
                    .controlSize(.large)

                Spacer()

                Button(permissions.isSatisfied ? "Get Started" : "Continue Anyway", action: onContinue)
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}
