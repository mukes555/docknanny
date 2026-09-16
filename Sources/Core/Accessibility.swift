import ApplicationServices
import AppKit
import Security

/// DockNanny's one optional permission, and what it is used for.
///
/// Every dock action goes through NSWorkspace and needs nothing. Three things
/// read another app's state, which is Accessibility's job: listing and
/// raising an app's windows from a tile's menu, keeping windows clear of the
/// docks, and the --probe-windows diagnostic. It is asked for from the setup
/// window or the Behavior pane, never at launch, and the docks work the same
/// without it.
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

/// One of an app's standard windows, with what a single round trip tells.
struct StandardWindow {
    let element: AXUIElement
    /// Where the app says the window is, in Accessibility's space; nil when
    /// the app would not say. The window server's word is preferred anyway.
    let reportedFrame: CGRect?
    let isMinimized: Bool
}

/// Reads and raises an app's windows through Accessibility.
@MainActor
enum AppWindows {
    /// A hung app would otherwise hold the caller, on the main thread, for
    /// the default six seconds per attribute. Set on the system-wide element
    /// it applies to every element this process talks to, so it has to be in
    /// place before the first message to any app, observers included.
    static func installMessagingTimeout() {
        _ = messagingTimeoutInstalled
    }

    private static let messagingTimeoutInstalled: Bool = {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
        return true
    }()

    /// More windows than this and a menu would scroll off the screen anyway;
    /// it also bounds the time spent talking to a slow app.
    private static let menuWindowLimit = 40
    /// The keeper has no menu to fit; an app with very many windows is bounded
    /// all the same, since each one is a round trip.
    private static let keeperWindowLimit = 200

    /// Palettes and system dialogs are windows to Accessibility but not to a
    /// person. Judged by exclusion because apps are loose with subroles:
    /// Electron has reported "unknown" for its windows, and some apps report
    /// none at all.
    private static let excludedSubroles: Set<String> = [
        kAXFloatingWindowSubrole, kAXSystemFloatingWindowSubrole, kAXSystemDialogSubrole
    ]

    /// nil when Accessibility has not been granted; empty when the app has no
    /// standard windows.
    static func list(processIdentifier pid: pid_t) -> [AppWindow]? {
        guard Accessibility.isTrusted else { return nil }
        installMessagingTimeout()

        let application = AXUIElementCreateApplication(pid)
        guard let elements = attribute(kAXWindowsAttribute, of: application) as? [AXUIElement] else { return [] }

        return elements.prefix(menuWindowLimit).enumerated().compactMap { index, element -> AppWindow? in
            let values = attributes(
                [kAXSubroleAttribute, kAXTitleAttribute, kAXMinimizedAttribute, kAXMainAttribute], of: element
            )
            // The Dock lists standard windows only; sheets and popovers are
            // not something a person picks from a menu.
            let subrole = values[0] as? String
            guard subrole == nil || subrole == kAXStandardWindowSubrole else { return nil }
            let title = values[1] as? String ?? ""
            return AppWindow(
                id: index,
                title: title.isEmpty ? "Untitled" : title,
                isMinimized: values[2] as? Bool ?? false,
                isMain: values[3] as? Bool ?? false,
                element: element
            )
        }
    }

    /// A window a person works in: a window by role, not a palette or a system
    /// dialog by subrole, and not full screen (its own Space, nothing to be
    /// clear of and nothing to hide it from). Minimized ones are included,
    /// since bringing them back is half of hiding a screen.
    static func standardWindows(processIdentifier pid: pid_t) -> [StandardWindow] {
        guard Accessibility.isTrusted else { return [] }
        installMessagingTimeout()

        let application = AXUIElementCreateApplication(pid)
        guard let elements = attribute(kAXWindowsAttribute, of: application) as? [AXUIElement] else { return [] }

        return elements.prefix(keeperWindowLimit).compactMap { element -> StandardWindow? in
            let values = attributes([
                kAXRoleAttribute, kAXSubroleAttribute, kAXMinimizedAttribute,
                "AXFullScreen", kAXPositionAttribute, kAXSizeAttribute
            ], of: element)
            let isWindow = values[0] as? String == kAXWindowRole
            let isExcluded = excludedSubroles.contains(values[1] as? String ?? "")
            let isFullScreen = values[3] as? Bool == true
            guard isWindow, !isExcluded, !isFullScreen else { return nil }

            var reported: CGRect?
            if let position = point(from: values[4]), let size = size(from: values[5]) {
                reported = CGRect(origin: position, size: size)
            }
            return StandardWindow(
                element: element, reportedFrame: reported, isMinimized: values[2] as? Bool ?? false
            )
        }
    }

    /// Every window the keeper should judge: a minimized one is under nothing.
    static func windowsToKeepClear(processIdentifier pid: pid_t) -> [StandardWindow] {
        standardWindows(processIdentifier: pid).filter { !$0.isMinimized }
    }

    /// Folds a window away, or brings it back and puts it in front. This is
    /// the only way to take one screen's windows out of sight: macOS hides
    /// whole applications and nothing smaller.
    static func setMinimized(_ minimized: Bool, of window: AXUIElement) {
        let value: CFBoolean = minimized ? kCFBooleanTrue : kCFBooleanFalse
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, value)
        guard !minimized else { return }
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
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

    // MARK: Frames, for the window keeper and the probe

    /// In Accessibility's space: origin at the top-left of the primary display.
    static func frame(of window: AXUIElement) -> CGRect? {
        guard let position = point(from: attribute(kAXPositionAttribute, of: window)),
              let size = size(from: attribute(kAXSizeAttribute, of: window)) else { return nil }
        return CGRect(origin: position, size: size)
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

    /// The keeper's rule, for the probe's report: a window a person works in.
    static func isStandardWindow(_ window: AXUIElement) -> Bool {
        guard attribute(kAXRoleAttribute, of: window) as? String == kAXWindowRole else { return false }
        let subrole = attribute(kAXSubroleAttribute, of: window) as? String ?? ""
        let minimized = attribute(kAXMinimizedAttribute, of: window) as? Bool ?? false
        return !excludedSubroles.contains(subrole) && !minimized
    }

    // MARK: Reading

    /// An app with a broken Accessibility implementation can answer a
    /// position request with anything; only a real AXValue is unpacked.
    private static func point(from object: AnyObject?) -> CGPoint? {
        var point = CGPoint.zero
        guard let value = axValue(object), AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private static func size(from object: AnyObject?) -> CGSize? {
        var size = CGSize.zero
        guard let value = axValue(object), AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private static func axValue(_ object: AnyObject?) -> AXValue? {
        guard let object, CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        // swiftlint:disable:next force_cast
        return (object as! AXValue)
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    /// Several attributes in one round trip, in the order asked for. An
    /// attribute the app lacks comes back as an AXValue carrying an error,
    /// which reads as nil here, the same as a single read that failed.
    private static func attributes(_ names: [String], of element: AXUIElement) -> [AnyObject?] {
        var array: CFArray?
        let status = AXUIElementCopyMultipleAttributeValues(element, names as CFArray, [], &array)
        guard status == .success, let values = array as? [AnyObject], values.count == names.count else {
            return Array(repeating: nil, count: names.count)
        }
        return values.map { value in
            guard let axValue = axValue(value), AXValueGetType(axValue) == .axError else { return value }
            return nil
        }
    }
}
