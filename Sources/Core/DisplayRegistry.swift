import AppKit

/// One attached display, reduced to what a dock needs to know about it.
struct Display: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    let frame: CGRect
    let visibleFrame: CGRect
    let backingScaleFactor: CGFloat
    let isPrimary: Bool
    let localizedName: String
}

/// Tracks attached displays and republishes them when the arrangement changes.
///
/// Displays are keyed by `CGDirectDisplayID` rather than by index, so a screen
/// that is unplugged and reconnected keeps its per-display settings instead of
/// inheriting whatever happens to be in the same array slot.
@MainActor
@Observable
final class DisplayRegistry {
    private(set) var displays: [Display] = []

    /// Height of the primary display, which is the pivot every Accessibility
    /// coordinate conversion turns on.
    private(set) var primaryHeight: CGFloat = 0

    private let observers = ObserverTokens(center: .default)
    private var rebuildTask: Task<Void, Never>?
    private let settleDelay: Duration

    /// Hot-plug fires `didChangeScreenParametersNotification` several times as
    /// the window server settles. Rebuilding on each one thrashes every panel,
    /// so changes are coalesced.
    init(settleDelay: Duration = .milliseconds(500)) {
        self.settleDelay = settleDelay
        rebuild()
        observeScreenChanges()
    }

    func display(withID id: CGDirectDisplayID) -> Display? {
        displays.first { $0.id == id }
    }

    private func observeScreenChanges() {
        let token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleRebuild()
            }
        }
        observers.add(token)
    }

    private func scheduleRebuild() {
        rebuildTask?.cancel()
        rebuildTask = Task { [weak self, settleDelay] in
            try? await Task.sleep(for: settleDelay)
            guard !Task.isCancelled else { return }
            self?.rebuild()
        }
    }

    private func rebuild() {
        let rebuilt = NSScreen.screens.compactMap(Self.describe)
        // Keep the last known pivot when the screen list is momentarily empty
        // (it is, during a display switch). Zeroing it would send every
        // Accessibility coordinate conversion to the wrong place.
        if let height = NSScreen.screens.first?.frame.height {
            primaryHeight = height
        }

        guard rebuilt != displays else { return }
        displays = rebuilt
        Log.display.info("Displays changed: \(rebuilt.count, privacy: .public) attached")
    }

    /// A screen with no `NSScreenNumber` cannot be keyed or persisted against,
    /// so it is dropped rather than given a synthesised identity.
    private static func describe(_ screen: NSScreen) -> Display? {
        guard let identifier = displayID(of: screen) else {
            Log.display.error("Screen has no NSScreenNumber; skipping")
            return nil
        }

        return Display(
            id: identifier,
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            backingScaleFactor: screen.backingScaleFactor,
            isPrimary: screen == NSScreen.screens.first,
            localizedName: screen.localizedName
        )
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }
}
