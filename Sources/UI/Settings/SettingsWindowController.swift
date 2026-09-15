import AppKit
import SwiftUI

/// Hosts the settings window.
///
/// Focus is arbitrated by ``ActivationPolicy`` rather than set here, so two
/// open windows cannot fight over the app's activation policy.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let navigation: SettingsNavigation

    init(store: SettingsStore, displays: DisplayRegistry, section: SettingsSection = .layout) {
        navigation = SettingsNavigation(section: section)
        let root = SettingsRootView(store: store, displays: displays, navigation: navigation)
        self.window = NSWindow(contentViewController: NSHostingController(rootView: root))

        super.init()

        window.delegate = self
        window.title = "DockNanny Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.setContentSize(CGSize(width: 900, height: 680))

        // The sidebar's material runs up under the traffic lights, so the
        // title bar has to be transparent and empty rather than merely styled.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)

        // Translucent: the root view lays down an NSVisualEffectView that
        // samples the desktop, and that only works through a clear window.
        window.isOpaque = false
        window.backgroundColor = .clear
    }

    var isShowing: Bool { window.isVisible }

    /// A window that is already open is brought forward where it is; only a
    /// fresh one is centred. A section named by the caller is shown; nil
    /// keeps the pane the person was on.
    func show(section: SettingsSection? = nil) {
        if let section {
            navigation.section = section
        }
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
