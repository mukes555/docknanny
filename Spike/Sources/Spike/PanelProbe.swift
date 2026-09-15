import AppKit

/// The single most important thing a dock must do: appear above other windows,
/// on every Space, without ever stealing keyboard focus from the app in front.
@MainActor
final class PanelProbe {
    private var panels: [NSPanel] = []
    private var wasActiveBeforeShowing = false

    func show() {
        wasActiveBeforeShowing = NSApp.isActive
        panels = NSScreen.screens.map(makePanel)
        for panel in panels {
            panel.orderFrontRegardless()
        }
    }

    func conclude() -> ProbeResult {
        let question = "Does a non-activating panel show without taking focus?"
        let stoleFocus = NSApp.isActive && !wasActiveBeforeShowing
        let visible = panels.filter(\.isVisible).count

        defer { dismiss() }

        guard !panels.isEmpty else {
            return ProbeResult(name: "Non-activating panel", question: question,
                               outcome: .unavailable("No panels were created."))
        }
        guard !stoleFocus else {
            return ProbeResult(name: "Non-activating panel", question: question,
                               outcome: .unavailable("Showing the panel activated the app."))
        }
        guard visible == panels.count else {
            return ProbeResult(name: "Non-activating panel", question: question,
                               outcome: .degraded("\(visible)/\(panels.count) panels became visible."))
        }

        return ProbeResult(
            name: "Non-activating panel",
            question: question,
            outcome: .available("\(visible) panel(s) shown, focus untouched."),
            notes: panels.map { "panel at \($0.frame.origin) on \($0.screen.map(describe) ?? "?")" }
        )
    }

    func dismiss() {
        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
    }

    /// The exact window configuration Phase 1 depends on.
    private func makePanel(for screen: NSScreen) -> NSPanel {
        let size = CGSize(width: 420, height: 72)
        let visible = screen.visibleFrame
        let origin = CGPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + 24
        )

        let panel = NSPanel(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.contentView = makeBackdrop(size: size)
        return panel
    }

    private func makeBackdrop(size: CGSize) -> NSView {
        let backdrop = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 22
        backdrop.layer?.masksToBounds = true

        let label = NSTextField(labelWithString: "DockNanny spike")
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.frame = CGRect(x: 0, y: size.height / 2 - 11, width: size.width, height: 22)
        label.alignment = .center
        backdrop.addSubview(label)
        return backdrop
    }

    private func describe(_ screen: NSScreen) -> String {
        DisplayProbe.displayID(of: screen).map { "display \($0)" } ?? "unknown display"
    }
}

/// macOS 26 renders Liquid Glass through a dedicated view class. Probed by name
/// so this spike still compiles and runs if the class is absent or renamed.
@MainActor
enum GlassProbe {
    static func run() -> ProbeResult {
        let question = "Is the native Tahoe glass material available to us?"
        let candidates = ["NSGlassEffectView", "NSGlassContainerView"]
        let found = candidates.filter { NSClassFromString($0) != nil }

        guard !found.isEmpty else {
            return ProbeResult(
                name: "Liquid Glass material",
                question: question,
                outcome: .degraded("No glass class found; fall back to NSVisualEffectView."),
                notes: ["Checked: \(candidates.joined(separator: ", "))"]
            )
        }

        return ProbeResult(
            name: "Liquid Glass material",
            question: question,
            outcome: .available("Found \(found.joined(separator: ", "))."),
            notes: ["NSVisualEffectView stays as the pre-26 fallback path."]
        )
    }
}
