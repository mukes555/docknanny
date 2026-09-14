import AppKit
import SwiftUI

/// Hosts the first-run wizard.
///
/// Focus is arbitrated by ``ActivationPolicy`` rather than set here, so closing
/// the wizard while the settings window is open does not strand it unfocusable.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let onOpenSettings: () -> Void

    init(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings

        let hosting = NSHostingController(rootView: AnyView(EmptyView()))
        self.window = NSWindow(contentViewController: hosting)

        super.init()

        hosting.rootView = AnyView(
            OnboardingView(
                onOpenSettings: { [weak self] in
                    self?.close()
                    onOpenSettings()
                },
                onDismiss: { [weak self] in self?.close() }
            )
        )

        configureWindow()
    }

    func show() {
        guard !window.isVisible else {
            ActivationPolicy.activate(bringingFront: window)
            return
        }
        window.center()
        ActivationPolicy.windowDidOpen(window)
    }

    func close() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        ActivationPolicy.windowDidClose(window)
    }

    private func configureWindow() {
        window.delegate = self
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.title = "Set Up macdock"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
    }
}
