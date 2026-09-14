import AppKit

/// Which display the system Dock is on right now.
///
/// There is no API for this, but the Dock's own window is display-sized and
/// sits at the Dock's window level, and the window list reports bounds and
/// owners to anyone without a permission. The display whose bounds it
/// overlaps most is the one it is on. The Dock moves between displays when
/// the pointer is pushed against another display's edge, with no
/// notification, so callers poll this.
enum SystemDockLocator {
    /// The window level the Dock draws at, from `kCGDockWindowLevelKey`.
    private static let dockLayer = 20

    nonisolated static func displayID() -> CGDirectDisplayID? {
        guard let dockBounds = dockWindowBounds() else { return nil }

        var count: UInt32 = 0
        var identifiers = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(UInt32(identifiers.count), &identifiers, &count) == .success else { return nil }

        let best = identifiers.prefix(Int(count)).max { lhs, rhs in
            overlap(of: dockBounds, with: lhs) < overlap(of: dockBounds, with: rhs)
        }
        // A Dock window that overlaps no display (mid-transition, or oddly
        // placed) must not pin the Dock to an arbitrary one.
        guard let best, overlap(of: dockBounds, with: best) > 0 else { return nil }
        return best
    }

    private static func overlap(of bounds: CGRect, with display: CGDirectDisplayID) -> CGFloat {
        let intersection = bounds.intersection(CGDisplayBounds(display))
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    /// The Dock has several windows; the one at the Dock's level is the Dock.
    private static func dockWindowBounds() -> CGRect? {
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        for window in windows
        where window[kCGWindowOwnerName as String] as? String == "Dock"
            && window[kCGWindowLayer as String] as? Int == dockLayer {
            guard let raw = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: raw) else { continue }
            return bounds
        }
        return nil
    }
}
