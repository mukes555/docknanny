import CoreGraphics

/// Where a dock sits along the edge it is anchored to.
enum DockAlignment: String, Codable, CaseIterable, Sendable {
    case start
    case center
    case end

    var localizedName: String {
        switch self {
        case .start: "Start"
        case .center: "Center"
        case .end: "End"
        }
    }
}

/// How the slab behind the tiles is drawn.
enum ChromeStyle: String, Codable, CaseIterable, Sendable {
    case glass
    case translucent
    case solid

    var localizedName: String {
        switch self {
        case .glass: "Liquid Glass"
        case .translucent: "Translucent"
        case .solid: "Solid"
        }
    }
}

/// The mark that says an application is running.
enum IndicatorStyle: String, Codable, CaseIterable, Sendable {
    case dot
    case line
    case none

    var localizedName: String {
        switch self {
        case .dot: "Dot"
        case .line: "Line"
        case .none: "None"
        }
    }
}

/// What clicking a tile does when its app is already frontmost.
///
/// Cycling an app's windows needs window identity, which arrives with
/// `WindowIndex` in Phase 3. It is deliberately absent rather than present and
/// quietly doing something else.
enum ActiveClickBehavior: String, Codable, CaseIterable, Sendable {
    case doNothing
    case hide

    var localizedName: String {
        switch self {
        case .doNothing: "Do Nothing"
        case .hide: "Hide the App"
        }
    }
}

/// Classic Dock magnification: tiles swell as the pointer nears them.
///
/// The curve is squared rather than linear so the peak is pronounced and the
/// falloff is gentle, which is what makes the effect read as fluid instead of
/// mechanical.
enum Magnification {
    static func scale(
        distance: CGFloat,
        influenceRadius: CGFloat,
        maximumScale: CGFloat
    ) -> CGFloat {
        guard influenceRadius > 0 else { return 1 }

        let normalised = min(1, max(0, distance / influenceRadius))
        let influence = 1 - normalised
        let eased = influence * influence

        return 1 + (maximumScale - 1) * eased
    }
}
