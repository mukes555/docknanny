import CoreGraphics

/// Translation between the two coordinate spaces DockNanny straddles.
///
/// Accessibility reports window geometry in a flipped space whose origin is
/// the **top-left of the primary display**. AppKit uses the bottom-left of
/// that same display. The pivot is therefore always the primary display's
/// height, never the height of the display a window happens to occupy, which
/// is the mistake that makes windows leap to the wrong place on mixed-height
/// multi-monitor setups.
///
/// Both directions are the same arithmetic: the conversion is its own inverse.
enum Coordinates {
    static func appKitRect(fromAccessibility rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        flippingVertically(rect, about: primaryHeight)
    }

    static func accessibilityRect(fromAppKit rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        flippingVertically(rect, about: primaryHeight)
    }

    static func appKitPoint(fromAccessibility point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    static func accessibilityPoint(fromAppKit point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Rect flips subtract the height as well, because the two spaces disagree
    /// about which corner `origin` names.
    private static func flippingVertically(_ rect: CGRect, about primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
