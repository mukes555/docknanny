import AppKit
import SwiftUI

/// Hosts the settings window.
///
/// Focus is arbitrated by ``ActivationPolicy`` rather than set here, so two
/// open windows cannot fight over the app's activation policy.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow

    init(store: SettingsStore, displays: DisplayRegistry, section: SettingsSection = .layout) {
        let root = SettingsRootView(store: store, displays: displays, initialSection: section)
        self.window = NSWindow(contentViewController: NSHostingController(rootView: root))

        super.init()

        window.delegate = self
        window.title = "macdock Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.setContentSize(CGSize(width: 900, height: 680))

        // The tab band runs the full width beneath the traffic lights, so the
        // title bar has to be transparent and empty rather than merely styled.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)

        // Translucent: the root view lays down an NSVisualEffectView that
        // samples the desktop, and that only works through a clear window.
        window.isOpaque = false
        window.backgroundColor = .clear
    }

    /// A window that is already open is brought forward where it is; only a
    /// fresh one is centred.
    func show() {
        guard !window.isVisible else {
            ActivationPolicy.activate(bringingFront: window)
            return
        }
        window.center()
        ActivationPolicy.windowDidOpen(window)
    }

    func windowWillClose(_ notification: Notification) {
        ActivationPolicy.windowDidClose(window)
    }
}
