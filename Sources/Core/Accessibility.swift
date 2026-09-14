import ApplicationServices
import AppKit

/// macdock's one optional permission, and the only thing it is used for.
///
/// Every dock action goes through NSWorkspace and needs nothing. Listing an
/// app's windows in a tile's menu, and raising one of them, is the one feature
/// that reads another app's state, and that is Accessibility's job. It is
/// asked for from the setup window, never at launch, and the docks work the
/// same without it.
enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// The system prompt, which offers to open System Settings. macOS shows
    /// it once per app; after that this just opens the pane.
    @MainActor
    static func request() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard !AXIsProcessTrustedWithOptions(options) else { return }
        openSystemSettings()
    }

    @MainActor
    static func openSystemSettings() {
        let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: pane) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// One window of a running application, as its tile menu lists it.
struct AppWindow: Identifiable {
    let id: Int
    let title: String
    let isMinimized: Bool
    /// The window the app would bring forward on activation.
    let isMain: Bool
    /// Kept for raising. AXUIElement is a CF object; it is used only on the
    /// main actor, like everything else here.
    let element: AXUIElement
}

/// Reads and raises an app's windows through Accessibility.
@MainActor
enum AppWindows {
    /// A hung app would otherwise hold the menu open for the default six
    /// seconds per attribute.
    private static let messagingTimeout: Float = 0.25

    /// nil when Accessibility has not been granted; empty when the app has no
    /// standard windows.
    static func list(processIdentifier pid: pid_t) -> [AppWindow]? {
        guard Accessibility.isTrusted else { return nil }

        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, messagingTimeout)
        guard let elements = attribute(kAXWindowsAttribute, of: application) as? [AXUIElement] else { return [] }

        return elements.enumerated().compactMap { index, element -> AppWindow? in
            // Palettes, sheets and popovers are windows to Accessibility but
            // not to a person; the Dock lists standard windows only.
            let subrole = attribute(kAXSubroleAttribute, of: element) as? String
            guard subrole == nil || subrole == kAXStandardWindowSubrole else { return nil }
            let title = attribute(kAXTitleAttribute, of: element) as? String ?? ""
            return AppWindow(
                id: index,
                title: title.isEmpty ? "Untitled" : title,
                isMinimized: attribute(kAXMinimizedAttribute, of: element) as? Bool ?? false,
                isMain: attribute(kAXMainAttribute, of: element) as? Bool ?? false,
                element: element
            )
        }
    }

    /// Un-minimizes if needed, brings the window forward, then activates the
    /// app; in the other order the app would raise its own main window over it.
    static func raise(_ window: AppWindow, of application: NSRunningApplication) {
        if window.isMinimized {
            AXUIElementSetAttributeValue(window.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        application.activate()
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
