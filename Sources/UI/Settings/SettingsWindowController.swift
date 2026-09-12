import AppKit
import SwiftUI

/// Hosts the settings window.
///
/// Focus is arbitrated by ``ActivationPolicy`` rather than set here, so two
/// open windows cannot fight over the app's activation policy.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow

    init(store: SettingsStore, displays: DisplayRegistry) {
        let root = SettingsRootView(store: store, displays: displays)
        self.window = NSWindow(contentViewController: NSHostingController(rootView: root))

        super.init()

        window.delegate = self
        window.title = "macdock Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.setContentSize(CGSize(width: 760, height: 520))
    }

    func show() {
        ActivationPolicy.windowDidOpen()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        ActivationPolicy.windowDidClose()
    }
}
