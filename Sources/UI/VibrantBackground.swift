import AppKit
import SwiftUI

/// A window-background material that lets the desktop show through.
///
/// SwiftUI's materials blend with the view behind them, not with the desktop;
/// only an NSVisualEffectView blending `.behindWindow` samples what is under
/// the window itself, which is what makes a settings window read as a pane of
/// dark glass rather than a dark rectangle.
struct VibrantBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
