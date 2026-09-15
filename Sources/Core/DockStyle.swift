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
/// The Dock's plain click opens a window when the app has none and otherwise
/// leaves it be; hiding is the one other thing people expect of it. Cycling
/// the app's windows is not offered: window identity exists
/// (PrivateSymbols.windowNumber) but the Dock's ordering does not, so the
/// option is absent rather than present and quietly doing something else.
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
