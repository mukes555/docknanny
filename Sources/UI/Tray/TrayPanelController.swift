import AppKit
import SwiftUI

/// The panel that drops from the menu bar mark.
///
/// An NSPopover rather than a menu: a menu can list actions but cannot show a
/// dock, and the whole point of this panel is seeing every display's dock and
/// changing it in place. Transient behaviour gives click-outside dismissal for
/// free.
@MainActor
final class TrayPanelController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()

    init(
        store: SettingsStore,
        displays: DisplayRegistry,
        onOpenSettings: @escaping (SettingsSection) -> Void,
        onQuit: @escaping () -> Void
    ) {
        super.init()

        let root = TrayView(
            store: store,
            displays: displays,
            onOpenSettings: { [weak self] section in
                self?.popover.performClose(nil)
                onOpenSettings(section)
            },
            onClose: { [weak self] in self?.popover.performClose(nil) },
            onQuit: onQuit
        )
        popover.contentViewController = NSHostingController(rootView: root)
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.delegate = self
    }

    func toggle(relativeTo anchor: NSView) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // Size the popover to its content BEFORE showing it. When NSPopover
        // learns the real size after the fact it grows the window from its
        // bottom-left corner, which for a panel hanging from the menu bar means
        // straight up off the top of the screen. Measured: it opened at ~340pt,
        // grew to 531, and the top ended 154pt above the screen.
        if let content = popover.contentViewController {
            content.view.layoutSubtreeIfNeeded()
            popover.contentSize = content.view.fittingSize
        }

        // The app activates first, so the popover opens into an active app and
        // takes key status as it appears. Shown into an inactive app it stays
        // a non-key window, and everything in it draws faded until clicked.
        // The deferred pass re-asserts key status once activation has landed.
        ActivationPolicy.activateNow()
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        ActivationPolicy.activate(bringingFront: popover.contentViewController?.view.window, orderingFront: false)
    }
}
