import AppKit
import ApplicationServices

/// A permission macdock needs, and how badly it needs it.
///
/// A case here becomes a consent prompt the moment it exists, because the
/// onboarding UI is driven from `allCases`. Only add one in the same change
/// that adds the code consuming it: asking for a capability no code path uses
/// is a promise the app cannot keep.
enum Permission: String, CaseIterable, Identifiable {
    case accessibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility: "Accessibility"
        }
    }

    var isRequired: Bool {
        self == .accessibility
    }

    var explanation: String {
        switch self {
        case .accessibility:
            "Lets macdock raise, move and minimise windows when you click a dock icon."
        }
    }

    /// Deep link into the exact System Settings pane, so nobody has to hunt.
    var settingsURL: URL? {
        let pane = switch self {
        case .accessibility: "Privacy_Accessibility"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
    }
}

/// Tracks and requests the system permissions macdock depends on.
///
/// macOS sends no notification when a permission is granted in System
/// Settings, so the only way to notice is to keep asking. Polling runs only
/// while the onboarding window is open.
@MainActor
@Observable
final class PermissionsService {
    private(set) var granted: Set<Permission> = []

    private var pollTask: Task<Void, Never>?

    init() {
        refresh()
    }

    var isSatisfied: Bool {
        Permission.allCases.filter(\.isRequired).allSatisfy(granted.contains)
    }

    func isGranted(_ permission: Permission) -> Bool {
        granted.contains(permission)
    }

    func refresh() {
        var current: Set<Permission> = []
        if AXIsProcessTrusted() { current.insert(.accessibility) }

        guard current != granted else { return }
        granted = current
    }

    func startPolling(every interval: Duration = .milliseconds(750)) {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                // Sleeping is where cancellation lands, so re-check before
                // doing another round of work.
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Asks the system to show its own permission dialog. The prompt appears
    /// only the first time; afterwards macOS silently does nothing, which is
    /// why the settings deep link is always offered alongside.
    func request(_ permission: Permission) {
        switch permission {
        case .accessibility:
            // kAXTrustedCheckOptionPrompt is exported as a mutable global, which
            // Swift 6 refuses to touch. Its value is this string and has been
            // since the API shipped.
            let promptKey = "AXTrustedCheckOptionPrompt"
            _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        }
        openSettings(for: permission)
    }

    func openSettings(for permission: Permission) {
        guard let url = permission.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }
}
