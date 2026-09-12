import SwiftUI

/// One permission, its current state, and the way to change it.
struct PermissionRow: View {
    let permission: Permission
    let isGranted: Bool
    let onGrant: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            statusIcon

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(permission.title)
                        .font(.system(size: 13, weight: .semibold))
                    if !permission.isRequired {
                        Text("Optional")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.15), in: .capsule)
                    }
                }
                Text(permission.explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            action
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 10))
    }

    private var statusIcon: some View {
        Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.system(size: 17))
            .foregroundStyle(isGranted ? BrandPalette.granted : BrandPalette.pending)
            .accessibilityLabel(isGranted ? "Granted" : "Not granted")
    }

    @ViewBuilder
    private var action: some View {
        if isGranted {
            Text("Granted")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            Button("Grant", action: onGrant)
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
        }
    }
}
