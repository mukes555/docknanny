import AppKit
import ApplicationServices

/// Puts the window a click brings into being on the screen whose dock was
/// clicked.
///
/// macOS decides where a new window goes, usually the screen that has focus,
/// and offers no way to ask for another. So the window is moved as soon as it
/// exists: what the app had before the click is noted, the window server is
/// watched for a window that was not there, and that one is moved across at
/// its own size. Only an app with no window at all is watched, so a window
/// someone opens by hand in an app they are already using is never touched.
@MainActor
enum NewWindowPlacer {
    /// Bubbles, palettes and splash screens are not what a click opens.
    private static let smallestDocumentWindow = CGSize(width: 240, height: 160)
    /// An app restoring several windows shows them within moments of each
    /// other; a window after that is the person's own doing.
    private static let siblingGrace = Duration.milliseconds(1500)
    /// A window the window server shows but Accessibility cannot find after
    /// this many looks is not a standard window, and is left where it is.
    private static let lookLimit = 20
    private static let tick = Duration.milliseconds(100)

    /// Every window the app has before it is asked to open, on any Space and
    /// minimized ones included, so none of them is mistaken for new. nil when
    /// the app already has a document window: then the click opens nothing
    /// new, and nothing should be watched for.
    static func windowsBefore(opening running: NSRunningApplication?) -> Set<CGWindowID>? {
        guard let running else { return [] }
        let windows = WindowServer.everyWindowBounds(ofProcess: running.processIdentifier)
        let hasDocumentWindow = windows.values.contains { isDocumentSized($0) }
        guard !hasDocumentWindow else { return nil }
        return Set(windows.keys)
    }

    /// Watches for windows that were not there before and moves each onto the
    /// screen. A launch can take seconds to show a window (VS Code takes
    /// several); a running app answers a reopen at once, so it gets less time.
    static func place(
        windowsOf pid: pid_t,
        notIn before: Set<CGWindowID>,
        onto screen: DockScreen,
        launched: Bool
    ) async {
        guard Accessibility.isTrusted else { return }

        let clock = ContinuousClock()
        var giveUpAt = clock.now + (launched ? .seconds(15) : .seconds(3))
        var settled = before
        var looks: [CGWindowID: Int] = [:]

        while clock.now < giveUpAt {
            let fresh = WindowServer.windowBounds(ofProcess: pid).filter { number, bounds in
                !settled.contains(number) && isDocumentSized(bounds)
            }
            // One Accessibility round per tick, and only when something new
            // has appeared: the window server is free to ask, the app is not.
            let elements = fresh.isEmpty ? [:] : standardWindowsByNumber(of: pid)

            for (number, bounds) in fresh {
                guard let element = elements[number] else {
                    // The app's Accessibility side lags its window server
                    // side by a moment; it is asked again next time round.
                    looks[number, default: 0] += 1
                    if looks[number, default: 0] >= lookLimit {
                        settled.insert(number)
                    }
                    continue
                }
                move(element, from: bounds, onto: screen)
                settled.insert(number)
                giveUpAt = min(giveUpAt, clock.now + siblingGrace)
            }
            try? await Task.sleep(for: tick)
        }
    }

    /// The window's own size, shrunk only where it does not fit, centred in
    /// the usable part of the screen. Centred rather than kept at the same
    /// offset: the spot an app picks on one screen means nothing on another
    /// of a different size.
    nonisolated static func centred(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        return CGRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func move(_ window: AXUIElement, from bounds: CGRect, onto screen: DockScreen) {
        let frame = Coordinates.appKitRect(fromAccessibility: bounds, primaryHeight: screen.primaryHeight)
        let isAlreadyThere = screen.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
        guard !isAlreadyThere else { return }

        let target = centred(size: frame.size, in: screen.visibleFrame)
        let accessibilityTarget = Coordinates.accessibilityRect(fromAppKit: target, primaryHeight: screen.primaryHeight)
        if let refusal = AppWindows.set(frame: accessibilityTarget, of: window) {
            Log.workspace.notice("An app refused to open on the clicked screen: \(refusal.rawValue, privacy: .public)")
            return
        }
        Log.workspace.info("Opened a window on the screen whose dock was clicked")
    }

    private static func standardWindowsByNumber(of pid: pid_t) -> [CGWindowID: AXUIElement] {
        var elements: [CGWindowID: AXUIElement] = [:]
        for window in AppWindows.standardWindows(processIdentifier: pid) {
            guard let number = PrivateSymbols.windowNumber(of: window.element) else { continue }
            elements[number] = window.element
        }
        return elements
    }

    private static func isDocumentSized(_ bounds: CGRect) -> Bool {
        bounds.width >= smallestDocumentWindow.width && bounds.height >= smallestDocumentWindow.height
    }
}
