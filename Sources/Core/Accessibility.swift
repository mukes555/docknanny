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
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return false }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess,
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
    /// A hung app would otherwise hold the caller, on the main thread, for
    /// the default six seconds per attribute. Set on the system-wide element
    /// it applies to every element this process talks to.
    private static let messagingTimeoutInstalled: Bool = {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
        return true
    }()

    /// More windows than this and a menu would scroll off the screen anyway;
    /// it also bounds the time spent talking to a slow app.
    private static let windowLimit = 40

    /// nil when Accessibility has not been granted; empty when the app has no
    /// standard windows.
    static func list(processIdentifier pid: pid_t) -> [AppWindow]? {
        guard Accessibility.isTrusted else { return nil }
        _ = messagingTimeoutInstalled

        let application = AXUIElementCreateApplication(pid)
        guard let elements = attribute(kAXWindowsAttribute, of: application) as? [AXUIElement] else { return [] }

        return elements.prefix(windowLimit).enumerated().compactMap { index, element -> AppWindow? in
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
        var position = CGPoint.zero
        var size = CGSize.zero
        guard read(attribute(kAXPositionAttribute, of: window), as: .cgPoint, into: &position),
              read(attribute(kAXSizeAttribute, of: window), as: .cgSize, into: &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// An app with a broken Accessibility implementation can answer a
    /// position request with anything; only a real AXValue is unpacked.
    private static func read<Value>(_ object: AnyObject?, as type: AXValueType, into result: inout Value) -> Bool {
        guard let object, CFGetTypeID(object) == AXValueGetTypeID() else { return false }
        // swiftlint:disable:next force_cast
        return AXValueGetValue(object as! AXValue, type, &result)
    }

    /// Position first, then size: an app clamps a size to its screen, so the
    /// move has to have happened before the shrink is judged. Returns the
    /// first error the app gave, or nil when it accepted both.
    @discardableResult
    static func set(frame: CGRect, of window: AXUIElement) -> AXError? {
        var position = frame.origin
        var size = frame.size
        var errors: [AXError] = []
        if let value = AXValueCreate(.cgPoint, &position) {
            errors.append(AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value))
        }
        if let value = AXValueCreate(.cgSize, &size) {
            errors.append(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value))
        }
        return errors.first { $0 != .success }
    }

    /// A window a person works in: a window by role, not a palette or a
    /// system dialog by subrole, and not minimized. The subrole is judged by
    /// exclusion because apps are loose with it: Electron reports "unknown"
    /// for every window it has, and some apps report none at all.
    static func isStandardWindow(_ window: AXUIElement) -> Bool {
        guard attribute(kAXRoleAttribute, of: window) as? String == kAXWindowRole else { return false }
        let subrole = attribute(kAXSubroleAttribute, of: window) as? String ?? ""
        let floating = [kAXFloatingWindowSubrole, kAXSystemFloatingWindowSubrole, kAXSystemDialogSubrole]
        let minimized = attribute(kAXMinimizedAttribute, of: window) as? Bool ?? false
        return !floating.contains(subrole) && !minimized
    }

    /// For the log, when a window is rejected: what it said it was. Logged
    /// as private: a window title is the person's business.
    static func describe(_ element: AXUIElement) -> String {
        let role = attribute(kAXRoleAttribute, of: element) as? String ?? "no role"
        let subrole = attribute(kAXSubroleAttribute, of: element) as? String ?? "no subrole"
        let title = attribute(kAXTitleAttribute, of: element) as? String ?? ""
        let minimized = attribute(kAXMinimizedAttribute, of: element) as? Bool ?? false
        var position: AnyObject?
        let positionStatus = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        return "\(role)/\(subrole) title=\(title.prefix(30)) minimized=\(minimized) position=\(positionStatus.rawValue)"
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
