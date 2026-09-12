import AppKit
import SwiftUI

/// Hosts the first-run wizard.
///
/// macdock normally runs as an accessory app, which cannot take keyboard focus
/// or appear in the command-tab switcher. The policy is raised to `.regular`
/// for as long as this window is open, then dropped again, so the wizard
/// behaves like a normal window without giving macdock a permanent Dock tile.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let permissions: PermissionsService

    init(permissions: PermissionsService) {
        self.permissions = permissions

        let hosting = NSHostingController(rootView: AnyView(EmptyView()))
        self.window = NSWindow(contentViewController: hosting)

        super.init()

        hosting.rootView = AnyView(
            OnboardingView(
                permissions: permissions,
                onRestart: { AppRestarter.restart() },
                onContinue: { [weak self] in self?.close() }
            )
        )

        configureWindow()
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        permissions.stopPolling()
        NSApp.setActivationPolicy(.accessory)
    }

    private func configureWindow() {
        window.delegate = self
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.title = "Set Up macdock"
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
    }
}
