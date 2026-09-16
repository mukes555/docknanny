import AppKit

/// `DockNanny --probe-open=<bundle id>`: clicks an app's tile the way the dock
/// on the screen under the pointer would, with new windows placed there, then
/// reports which screen each of the app's windows ended up on.
///
/// It goes through the same call a dock click makes, so what it reports is
/// what a click would do. Launch it the way macOS launches apps
/// (`open -n -a DockNanny --args --probe-open=com.microsoft.VSCode`), since a
/// process started from a shell carries the shell's identity for permission
/// checks. The report is in the log under the "probe" category.
@MainActor
enum NewWindowProbe {
    /// Long enough for a slow launch to show its window and be placed.
    private static let wait = Duration.seconds(20)

    static func run(bundleIdentifier: String) async {
        let pointer = NSEvent.mouseLocation
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height,
              let clicked = screens.first(where: { $0.frame.contains(pointer) }) ?? screens.first else {
            say("No screen to click on")
            return
        }
        let screen = DockScreen(frame: clicked.frame, visibleFrame: clicked.visibleFrame, primaryHeight: primaryHeight)
        let wasRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
        say("Clicking \(bundleIdentifier) on the dock on \(clicked.localizedName); running before: \(wasRunning)")

        AppActivator.activate(
            bundleIdentifier: bundleIdentifier,
            whenActive: .doNothing,
            on: screen,
            placesNewWindows: true
        )
        try? await Task.sleep(for: wait)
        report(bundleIdentifier: bundleIdentifier, clicked: clicked, primaryHeight: primaryHeight)
    }

    private static func report(bundleIdentifier: String, clicked: NSScreen, primaryHeight: CGFloat) {
        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleIdentifier
        }) else {
            say("The app is not running after the click")
            return
        }

        let windows = WindowServer.windowBounds(ofProcess: application.processIdentifier)
            .filter { $0.value.width >= 240 && $0.value.height >= 160 }
        say("Document windows on screen after \(wait): \(windows.count)")
        var onClickedScreen = 0
        for (number, bounds) in windows.sorted(by: { $0.key < $1.key }) {
            let frame = Coordinates.appKitRect(fromAccessibility: bounds, primaryHeight: primaryHeight)
            let centre = CGPoint(x: frame.midX, y: frame.midY)
            let screenName = NSScreen.screens.first { $0.frame.contains(centre) }?.localizedName ?? "no screen"
            if clicked.frame.contains(centre) {
                onClickedScreen += 1
            }
            say("  window \(number): \(describe(frame)) on \(screenName)")
        }
        let placed = "\(onClickedScreen) of \(windows.count) on the clicked screen"
        say("Verdict: \(windows.isEmpty ? "no window opened" : placed)")
    }

    /// Numbers only: no titles, so the log stays public.
    private static func describe(_ rect: CGRect) -> String {
        "\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height))"
    }

    private static func say(_ line: String) {
        Log.probe.info("\(line, privacy: .public)")
    }
}
