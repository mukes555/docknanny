import AppKit

/// Phase 0 entry point.
///
/// Runs as an accessory app (no Dock tile of its own) because that is the
/// activation policy DockNanny itself will use, and it is the only way the
/// non-activating panel check means anything.
@MainActor
final class SpikeDelegate: NSObject, NSApplicationDelegate {
    private let panelProbe = PanelProbe()
    private let panelVisibleSeconds = 4

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelProbe.show()

        Task { @MainActor [panelProbe, panelVisibleSeconds] in
            let symbols = SystemSymbols.resolved
            var results = [
                DisplayProbe.run(),
                GlassProbe.run(),
                WindowIDProbe.run(symbols: symbols),
                SpacesProbe.run(symbols: symbols)
            ]

            // Leave the panels up long enough to be looked at, since "does it
            // steal focus" is ultimately a question about what the user sees.
            try? await Task.sleep(for: .seconds(panelVisibleSeconds))
            results.append(panelProbe.conclude())

            print(ProbeReport.render(results))
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let delegate = SpikeDelegate()
application.delegate = delegate
application.run()
