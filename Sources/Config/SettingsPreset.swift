import Foundation

/// A starting point: one click that sets the look and behaviour, and leaves
/// what is pinned alone.
///
/// Presets are applied, not selected: after one is applied every value is an
/// ordinary setting, so there is no "modified preset" state to explain.
enum SettingsPreset: String, CaseIterable, Identifiable {
    case matchDock
    case minimal
    case playful
    case tuckedAway

    var id: String { rawValue }

    var title: String {
        switch self {
        case .matchDock: "Match the Dock"
        case .minimal: "Minimal"
        case .playful: "Playful"
        case .tuckedAway: "Tucked Away"
        }
    }

    var summary: String {
        switch self {
        case .matchDock:
            "Everything the system Dock does, on every display: its apps, edge, size, magnification and hiding."
        case .minimal:
            "Small icons, no magnification, a thin line under running apps. Out of the way without hiding."
        case .playful:
            "Big icons, strong magnification, a lime tint. The one for showing off."
        case .tuckedAway:
            "Hidden until the pointer touches the edge, then quick to appear."
        }
    }

    var symbol: String {
        switch self {
        case .matchDock: "macwindow"
        case .minimal: "minus"
        case .playful: "sparkles"
        case .tuckedAway: "eye.slash"
        }
    }

    /// Changes look and behaviour only. Pins, per-display overrides and the
    /// keyboard shortcuts are the user's and survive every preset.
    func apply(to settings: inout Settings, dock: SystemDockMonitor.Snapshot) {
        switch self {
        case .matchDock:
            applyDockLook(to: &settings, dock: dock)
        case .minimal:
            settings.iconSize = 40
            settings.itemSpacing = 4
            settings.margin = 0
            settings.chromeStyle = .translucent
            settings.indicatorStyle = .line
            settings.tint = .none
            settings.isMagnificationEnabled = false
            settings.autoHide = false
        case .playful:
            settings.iconSize = 56
            settings.itemSpacing = 8
            settings.margin = 10
            settings.chromeStyle = .glass
            settings.indicatorStyle = .dot
            settings.tint = .lime
            settings.isMagnificationEnabled = true
            settings.magnificationScale = 1.8
            settings.autoHide = false
        case .tuckedAway:
            settings.iconSize = 44
            settings.margin = 0
            settings.chromeStyle = .translucent
            settings.indicatorStyle = .dot
            settings.isMagnificationEnabled = false
            settings.autoHide = true
            settings.autoHideDelay = 0.1
        }
    }

    /// The Dock's own preferences, read at the moment of applying.
    private func applyDockLook(to settings: inout Settings, dock: SystemDockMonitor.Snapshot) {
        settings.edge = dock.edge ?? .bottom
        settings.iconSize = (dock.tileSize ?? 48).clamped(to: Settings.Limits.iconSize)
        settings.isMagnificationEnabled = dock.magnifiedTileSize != nil
        if let tileSize = dock.tileSize, let magnified = dock.magnifiedTileSize, tileSize > 0 {
            settings.magnificationScale = (magnified / tileSize).clamped(to: Settings.Limits.scale)
        }
        settings.autoHide = dock.autoHides
        settings.autoHideDelay = 0.15
        settings.itemSpacing = 6
        settings.margin = 4
        settings.chromeStyle = .glass
        settings.indicatorStyle = .dot
        settings.tint = .none
        settings.mirrorSystemDock = true
        settings.showTrash = true
        settings.showRunningApps = true
    }
}
