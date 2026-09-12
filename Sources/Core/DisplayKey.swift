// CGDisplayCreateUUIDFromDisplayID is declared in ColorSync, not CoreGraphics,
// despite the CG prefix.
import ColorSync
import CoreGraphics
import Foundation

/// A stable identifier for a display, used to key per-display settings.
///
/// `CGDirectDisplayID` is assigned per session: unplug a monitor and plug it
/// back in and it can differ, which means per-display configuration keyed on it
/// is silently discardable. The window-server UUID survives reconnection and
/// reboots, so "the settings I chose for the monitor on my desk" survive with
/// it. Without this, per-display depth is a feature that quietly forgets.
struct DisplayKey: Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Falls back to the session id when no UUID is available, which is better
    /// than refusing to store anything at all: the settings then last for the
    /// session rather than forever.
    init(displayID: CGDirectDisplayID) {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String? else {
            self.rawValue = "id:\(displayID)"
            return
        }
        self.rawValue = string
    }

    /// How a pre-`DisplayKey` settings file spelled this display. Read as a
    /// fallback so upgrading does not discard a user's per-display setup; the
    /// next write stores the stable form.
    static func legacy(displayID: CGDirectDisplayID) -> String {
        String(displayID)
    }
}
