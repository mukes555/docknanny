import CoreGraphics

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
