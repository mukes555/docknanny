import AppKit
import ApplicationServices

/// `DockNanny --probe-hide=<app name>`: what "Hide on This Screen" would do to
/// an app on the screen under the pointer, and with `--apply`, doing it and
/// checking that it took.
///
/// The click itself cannot be rehearsed, but everything behind it can: the
/// windows an app admits to, where the window server says each one is, which
/// screen that lands on, and whether a fold actually folded. Launch it the way
/// macOS launches apps (`open -n -a DockNanny --args --probe-hide=Finder`),
/// because a process started from a shell carries the shell's identity for
/// permission checks. The report is in the log under the "probe" category.
@MainActor
enum ScreenHidingProbe {
    static func run(appNamed name: String, applies: Bool) async {
        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName == name || $0.bundleIdentifier == name
        }) else {
            say("No running app named \(name)")
            return
        }
        guard let screen = screenUnderPointer() else {
            say("No screen under the pointer")
            return
        }

        let pid = application.processIdentifier
        say("\(name) pid \(pid), active: \(application.isActive), Accessibility trusted: \(Accessibility.isTrusted)")
        say("Screen: \(describe(screen.frame)), primary height \(Int(screen.primaryHeight))")

        let plan = ScreenHider.plan(for: pid, on: screen)
        report(plan, on: screen)
        compareSources(pid: pid, primaryHeight: screen.primaryHeight)
        guard applies else { return }
        await applyAndCheck(plan, pid: pid, on: screen)
    }

    private static func report(_ plan: ScreenHider.Plan, on screen: DockScreen) {
        say("Standard windows, placed (AppKit coordinates):")
        for (position, window) in plan.windows.enumerated() {
            let here = screen.frame.contains(CGPoint(x: window.frame.midX, y: window.frame.midY))
            let state = window.isMinimized ? "folded away" : "on screen"
            say("  [\(position)] \(describe(window.frame)) \(state), on this screen: \(here)")
        }
        say("Decision: \(describe(plan.action))")
    }

    /// Both sources, side by side, for one window at a time: the window server
    /// describes where a folded-away window's thumbnail is, the app describes
    /// where the window itself belongs, and they disagree while the fold is
    /// still animating.
    private static func compareSources(pid: pid_t, primaryHeight: CGFloat) {
        let bounds = WindowServer.everyWindowBounds(ofProcess: pid)
        say("Sources, window by window:")
        for (position, window) in AppWindows.standardWindows(processIdentifier: pid).enumerated() {
            let number = PrivateSymbols.windowNumber(of: window.element)
            let server = number.flatMap { bounds[$0] }
                .map { describe(Coordinates.appKitRect(fromAccessibility: $0, primaryHeight: primaryHeight)) }
            let reported = window.reportedFrame
                .map { describe(Coordinates.appKitRect(fromAccessibility: $0, primaryHeight: primaryHeight)) }
            let state = window.isMinimized ? "folded away" : "on screen"
            say("  [\(position)] \(state) server: \(server ?? "nothing"), app: \(reported ?? "nothing")")
        }
    }

    /// Does it, then reads every window back to see whether the apps agreed.
    private static func applyAndCheck(_ plan: ScreenHider.Plan, pid: pid_t, on screen: DockScreen) async {
        let wanted: Bool
        switch plan.action {
        case .minimize: wanted = true
        case .restore: wanted = false
        case .nothing:
            say("Nothing to apply")
            return
        }

        let touched = ScreenHider.apply(plan)
        say("Applied to \(touched) window(s); waiting for the apps to catch up")
        try? await Task.sleep(for: .seconds(1))

        compareSources(pid: pid, primaryHeight: screen.primaryHeight)
        let after = ScreenHider.plan(for: pid, on: screen)
        let targets = plan.targets.count
        let agreed = after.windows.filter { $0.isMinimized == wanted }.count
        say("After: \(describe(after.action))")
        for (position, window) in after.windows.enumerated() {
            say("  [\(position)] \(describe(window.frame)) \(window.isMinimized ? "folded away" : "on screen")")
        }
        let verdict = agreed >= targets ? "took" : "did not take on every window"
        say("Verdict: asked \(targets), now \(wanted ? "folded away" : "on screen"): \(agreed). The fold \(verdict).")
    }

    /// The screen the pointer is on, which is the dock a person would have
    /// clicked, or the primary one when the pointer is nowhere.
    private static func screenUnderPointer() -> DockScreen? {
        let pointer = NSEvent.mouseLocation
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height else { return nil }
        let screen = screens.first { $0.frame.contains(pointer) } ?? screens.first
        return screen.map { DockScreen(frame: $0.frame, primaryHeight: primaryHeight) }
    }

    private static func describe(_ action: ScreenHiding.Action) -> String {
        switch action {
        case .minimize(let positions): "fold away \(positions.count) window(s) at \(positions)"
        case .restore(let positions): "bring back \(positions.count) window(s) at \(positions)"
        case .nothing: "nothing on this screen"
        }
    }

    /// Numbers only: no titles, so the log stays public.
    private static func describe(_ rect: CGRect) -> String {
        "\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height))"
    }

    private static func say(_ line: String) {
        Log.probe.info("\(line, privacy: .public)")
    }
}
