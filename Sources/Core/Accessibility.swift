import ApplicationServices
import AppKit
import Security

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

    /// macOS keys a grant to the app's designated requirement. A plain ad hoc
    /// signature's requirement is a hash of the binary, so every rebuild is a
    /// new app and the grant silently stops applying. tools/dev.sh signs with
    /// the bundle identifier as the requirement instead, which survives
    /// rebuilds; this is true only for a build signed the naive way.
    static var grantIsTiedToThisExactBinary: Bool {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(code, [], &requirement) == errSecSuccess,
              let requirement else { return false }
        var text: CFString?
        guard SecRequirementCopyString(requirement, [], &text) == errSecSuccess, let text else { return false }
        return (text as String).hasPrefix("cdhash")
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

    // MARK: Frames, for the window keeper

    /// In Accessibility's space: origin at the top-left of the primary display.
    static func frame(of window: AXUIElement) -> CGRect? {
        guard let positionValue = attribute(kAXPositionAttribute, of: window),
              let sizeValue = attribute(kAXSizeAttribute, of: window) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              // swiftlint:disable:next force_cast
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Position first, then size: an app clamps a size to its screen, so the
    /// move has to have happened before the shrink is judged.
    static func set(frame: CGRect, of window: AXUIElement) {
        var position = frame.origin
        var size = frame.size
        if let value = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }

    static func isStandardWindow(_ window: AXUIElement) -> Bool {
        let subrole = attribute(kAXSubroleAttribute, of: window) as? String
        let minimized = attribute(kAXMinimizedAttribute, of: window) as? Bool ?? false
        return (subrole == nil || subrole == kAXStandardWindowSubrole) && !minimized
    }

    /// A full-screen window has its own Space and nothing to be clear of.
    static func isFullScreen(_ window: AXUIElement) -> Bool {
        attribute("AXFullScreen", of: window) as? Bool ?? false
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
