import AppKit
import ApplicationServices

/// The keeper's verdict on a window: where it is, whether that is under a
/// dock, and the move that takes it out.
extension WindowKeeper {
    private static let smallestDocumentWindow = CGSize(width: 240, height: 160)

    func judgeWindows(of pid: pid_t) {
        judgeWindows(of: pid, onScreen: WindowServer.windowBounds(ofProcess: pid))
    }

    /// The window server's bounds are the truth; an app's own report is the
    /// fallback for a window the server cannot be asked about. A single
    /// notification can carry a stale element, and a zoom can move more than
    /// one window; the list is the truth either way.
    func judgeWindows(of pid: pid_t, onScreen: [CGWindowID: CGRect]) {
        for window in AppWindows.windowsToKeepClear(processIdentifier: pid) {
            let truth = PrivateSymbols.windowNumber(of: window.element).flatMap { onScreen[$0] }
            nudgeIfNeeded(window, onScreen: truth)
        }
    }

    private func nudgeIfNeeded(_ window: KeptWindow, onScreen: CGRect?) {
        guard let reported = onScreen ?? window.reportedFrame else { return }

        let primaryHeight = displays.primaryHeight
        let frame = Coordinates.appKitRect(fromAccessibility: reported, primaryHeight: primaryHeight)
        // Bubbles, tooltips and menus are windows to Accessibility too, and
        // anchored to something; moving one would be worse than leaving it.
        guard frame.width >= Self.smallestDocumentWindow.width,
              frame.height >= Self.smallestDocumentWindow.height else {
            Log.workspace.info("Window changed but is too small to be a document window; left alone")
            return
        }
        guard let reservation = coordinator.reservation(at: CGPoint(x: frame.midX, y: frame.midY)) else {
            Log.workspace.info("Window changed on a display with no claim")
            return
        }
        guard let cleared = WindowNudge.clearedFrame(
            window: frame, visibleFrame: reservation.visibleFrame, strip: reservation.strip, edge: reservation.edge
        ) else {
            let place = "\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))"
            let strip = "\(Int(reservation.strip.minX)),\(Int(reservation.strip.minY)) "
                + "\(Int(reservation.strip.width))x\(Int(reservation.strip.height))"
            Log.workspace.info("Window at \(place, privacy: .public) is clear of strip \(strip, privacy: .public)")
            return
        }

        let target = Coordinates.accessibilityRect(fromAppKit: cleared, primaryHeight: primaryHeight)
        if let refusal = AppWindows.set(frame: target, of: window.element) {
            Log.workspace.notice("An app refused the nudge: \(refusal.rawValue, privacy: .public)")
            return
        }
        Log.workspace.info("Nudged a window clear of the dock")
        verifyLater(window.element, expected: target)
    }

    /// An app can accept a frame and not apply it (iTerm2 echoes the request
    /// back through Accessibility while the window stays put), so the window
    /// server is asked shortly afterwards whether the move really happened.
    private func verifyLater(_ element: AXUIElement, expected: CGRect) {
        guard let number = PrivateSymbols.windowNumber(of: element) else { return }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard let actual = WindowServer.windowBounds(ofProcess: pid)[number] else { return }
            let took = abs(actual.width - expected.width) < 2 && abs(actual.height - expected.height) < 2
            let size = "\(Int(actual.width))x\(Int(actual.height)) "
                + "wanted \(Int(expected.width))x\(Int(expected.height))"
            if took {
                Log.workspace.info("The nudge took: \(size, privacy: .public)")
            } else {
                Log.workspace.notice("The nudge was accepted but not applied: \(size, privacy: .public)")
            }
        }
    }
}
