import AppKit
import SwiftUI

/// Hosts the settings window.
///
/// Like the setup wizard, this raises the activation policy so an accessory
/// app can present a normal, focusable window, then drops it again on close.
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
