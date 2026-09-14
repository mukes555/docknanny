import AppKit
import ApplicationServices

/// `macdock --probe-windows=<app name>`: records what Accessibility and the
/// window server each say about an app's windows, then exits.
///
/// The keeper's decisions rest on both, and apps are loose with the first: a
/// support question about a window that will not nudge is answered by this
/// in seconds, with macdock's own Accessibility grant, where a bug report
/// would take a week of guessing. Read-only. It has to be launched the way
/// macOS launches apps (`open -a macdock --args --probe-windows=iTerm2`),
/// because a process started from a shell carries the shell's identity for
/// permission checks; the report is in the log under the "probe" category.
@MainActor
enum WindowProbe {
    /// Notifications seen while a resize test runs, for the report. The
    /// observer callback is a C function pointer, which cannot hop actors,
    /// so the list is touched from the main thread without the checker's
    /// help; the callback runs there because its source is on the main loop.
    nonisolated(unsafe) private static var heard: [String] = []

    private static let noteNotification: AXObserverCallback = { _, _, notification, _ in
        heard.append(notification as String)
    }

    static func run(appNamed name: String, resizes: Bool, width: Double? = nil) async {
        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName == name || $0.bundleIdentifier == name
        }) else {
            say("No running app named \(name)")
            return
        }
        let pid = application.processIdentifier
        say("\(name) pid \(pid), Accessibility trusted: \(Accessibility.isTrusted), resize test: \(resizes)")
        report(pid: pid)
        if resizes {
            await resizeTest(pid: pid)
        }
        if let width {
            setWidth(width, pid: pid)
        }
    }

    /// Leaves the main window at the given width: a way to put a window
    /// under a dock on purpose, to test what the keeper does about it.
    private static func setWidth(_ width: Double, pid: pid_t) {
        let element = AXUIElementCreateApplication(pid)
        guard let window = windows(of: element, attribute: kAXMainWindowAttribute).first,
              let number = PrivateSymbols.windowNumber(of: window),
              let current = WindowServer.windowBounds(ofProcess: pid)[number] else {
            say("Set width: no main window")
            return
        }
        let wanted = CGRect(x: current.minX, y: current.minY, width: width, height: current.height)
        let refusal = AppWindows.set(frame: wanted, of: window)
        say("Set width to \(Int(width)): \(refusal.map { "refused \($0.rawValue)" } ?? "accepted")")
    }

    /// Shrinks the app's main window by 30 points for a second, watching for
    /// the notifications an app is supposed to post and checking with the
    /// window server whether the request was applied, then puts it back.
    private static func resizeTest(pid: pid_t) async {
        let element = AXUIElementCreateApplication(pid)
        guard let window = windows(of: element, attribute: kAXMainWindowAttribute).first,
              let number = PrivateSymbols.windowNumber(of: window),
              let before = WindowServer.windowBounds(ofProcess: pid)[number] else {
            say("Resize test: no main window to try")
            return
        }

        var observer: AXObserver?
        let created = AXObserverCreate(pid, noteNotification, &observer)
        if created == .success, let observer {
            for name in [kAXWindowResizedNotification, kAXWindowMovedNotification, kAXWindowCreatedNotification] {
                let added = AXObserverAddNotification(observer, element, name as CFString, nil)
                say("Observe \(name): \(added == .success ? "ok" : "error \(added.rawValue)")")
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        } else {
            say("Resize test: could not create an observer (\(created.rawValue))")
        }

        let smaller = CGRect(x: before.minX, y: before.minY, width: before.width - 30, height: before.height)
        let refusal = AppWindows.set(frame: smaller, of: window)
        say("Asked for \(describe(smaller)): \(refusal.map { "refused \($0.rawValue)" } ?? "accepted")")
        try? await Task.sleep(for: .seconds(1))
        let after = WindowServer.windowBounds(ofProcess: pid)[number].map(describe) ?? "gone"
        say("Window server after 1 s: \(after)")
        say("Notifications heard: \(heard.isEmpty ? "none" : heard.joined(separator: ", "))")

        AppWindows.set(frame: before, of: window)
        try? await Task.sleep(for: .milliseconds(500))
        let restored = WindowServer.windowBounds(ofProcess: pid)[number].map(describe) ?? "gone"
        say("Restored to \(restored)")
    }

    private static func report(pid: pid_t) {
        say("Window server, on screen, layer 0:")
        for (number, bounds) in WindowServer.windowBounds(ofProcess: pid).sorted(by: { $0.key < $1.key }) {
            say("  window \(number): \(describe(bounds))")
        }

        say("Accessibility, every element in AXWindows:")
        let element = AXUIElementCreateApplication(pid)
        for (index, window) in windows(of: element, attribute: kAXWindowsAttribute).enumerated() {
            say("  [\(index)] \(describe(window))")
        }
        for window in windows(of: element, attribute: kAXFocusedWindowAttribute) {
            say("Focused window: \(describe(window))")
        }
        for window in windows(of: element, attribute: kAXMainWindowAttribute) {
            say("Main window: \(describe(window))")
        }
    }

    private static func windows(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        if let list = value as? [AXUIElement] { return list }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return [] }
        // swiftlint:disable:next force_cast
        return [value as! AXUIElement]
    }

    /// Numbers, roles and frames only: no titles, so the log stays public.
    private static func describe(_ window: AXUIElement) -> String {
        let number = PrivateSymbols.windowNumber(of: window).map(String.init) ?? "no number"
        let frame = AppWindows.frame(of: window).map(describe) ?? "no frame"
        var role: AnyObject?
        var subrole: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole)
        let kind = "\(role as? String ?? "no role")/\(subrole as? String ?? "no subrole")"
        return "number \(number), frame \(frame), \(kind), standard: \(AppWindows.isStandardWindow(window))"
    }

    private static func describe(_ rect: CGRect) -> String {
        "\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height))"
    }

    private static func say(_ line: String) {
        Log.probe.info("\(line, privacy: .public)")
    }
}
