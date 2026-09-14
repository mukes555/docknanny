import AppKit

/// Keeps one dock panel per eligible display in step with the world.
///
/// Everything upstream is `@Observable`, so rather than wiring a notification
/// per source this watches all of them and re-synchronises whenever any
/// changes. Panels are keyed by display id, so a screen that disappears takes
/// its panel with it and a reconnected one gets its settings back.
@MainActor
final class DockCoordinator {
    private let displays: DisplayRegistry
    private let apps: RunningAppsMonitor
    private let settings: SettingsStore
    private let openSetup: () -> Void

    private var controllers: [CGDirectDisplayID: DockPanelController] = [:]
    private let systemDock = SystemDockMonitor()
    private let metadata = AppMetadataCache()

    /// Built once and shared by every panel. The closures read current state
    /// when they run rather than closing over a snapshot, so a panel created
    /// before a setting changed still behaves correctly afterwards.
    private lazy var actions = makeActions()

    init(
        displays: DisplayRegistry,
        apps: RunningAppsMonitor,
        settings: SettingsStore,
        openSetup: @escaping () -> Void
    ) {
        self.displays = displays
        self.apps = apps
        self.settings = settings
        self.openSetup = openSetup

        synchronise()
        observe()
    }

    func closeAll() {
        for controller in controllers.values {
            controller.close()
        }
        controllers.removeAll()
    }

    /// A dock's claim on its display, for keeping windows clear of it. nil
    /// where there is no dock, or where it hides itself and so claims nothing,
    /// as the system Dock claims nothing while auto-hidden.
    struct Reservation {
        let strip: CGRect
        let edge: DockEdge
        let visibleFrame: CGRect
    }

    func reservation(at point: CGPoint) -> Reservation? {
        guard let display = displays.displays.first(where: { $0.frame.contains(point) }),
              let controller = controllers[display.id],
              !controller.configuration.autoHide else { return nil }
        let edge = controller.configuration.edge
        let strip = WindowNudge.reservedStrip(
            edge: edge, thickness: controller.reservedThickness, visibleFrame: display.visibleFrame
        )
        return Reservation(strip: strip, edge: edge, visibleFrame: display.visibleFrame)
    }

    /// The shortcut's target is the dock the person is looking at: the one on
    /// the display under the pointer, or failing that any dock. Spacers do
    /// not count; people count icons.
    func activateTile(number: Int) {
        let pointer = NSEvent.mouseLocation
        let underPointer = displays.displays.first { $0.frame.contains(pointer) }
        let controller = underPointer.flatMap { controllers[$0.id] } ?? controllers.values.first
        guard let controller else { return }

        let apps = controller.items.filter { $0.bundleIdentifier != nil }
        guard number >= 1, number <= apps.count else { return }
        activate(apps[number - 1])
    }

    /// `withObservationTracking` fires once per change, so the observation is
    /// re-armed after each synchronise. The hop through a task matters: the
    /// callback runs *before* the new value is readable.
    private func observe() {
        withObservationTracking {
            _ = displays.displays
            _ = apps.apps
            _ = settings.settings
            _ = systemDock.snapshot
        } onChange: {
            Task { @MainActor [weak self] in
                self?.synchronise()
                self?.observe()
            }
        }
    }

    private func synchronise() {
        var surviving: Set<CGDirectDisplayID> = []
        let effective = effectiveSettings

        for display in displays.displays {
            let configuration = effective.resolved(for: display)
            guard configuration.isEnabled else { continue }

            surviving.insert(display.id)
            let items = buildItems(for: configuration)

            if let existing = controllers[display.id] {
                existing.update(display: display, configuration: configuration, items: items)
            } else {
                controllers[display.id] = DockPanelController(
                    display: display,
                    configuration: configuration,
                    items: items,
                    actions: actions,
                    onDragOutside: { [weak self] item, point in
                        self?.dragReleased(item, atScreenPoint: point, from: display.id) ?? .cancelled
                    }
                )
            }
        }

        closeControllers(notIn: surviving)
    }

    private func buildItems(for configuration: ResolvedDockConfiguration) -> [DockItem] {
        let source = DockSource(
            pinned: configuration.pinnedBundleIdentifiers,
            running: apps.apps,
            recents: settings.settings.mirrorSystemDock ? systemDock.recents : nil,
            others: configuration.pinnedOthers,
            showsTrash: configuration.showTrash,
            isTrashFull: systemDock.isTrashFull
        )
        return DockContents.items(
            source: source,
            configuration: configuration,
            iconProvider: metadata.icon(for:),
            nameProvider: metadata.name(for:)
        )
    }

    /// Global settings with the system Dock's lists substituted in while
    /// mirroring. Settings stays a pure value type; the substitution lives here
    /// because this is the one place that knows both sources. Finder is the
    /// Dock's first tile without ever being in its pin list.
    private var effectiveSettings: Settings {
        var effective = settings.settings
        guard effective.mirrorSystemDock else { return effective }

        let finder = "com.apple.finder"
        effective.pinnedBundleIdentifiers = [finder] + systemDock.pins.filter { $0 != finder }
        effective.pinnedOthers = systemDock.others
        return effective
    }

    // MARK: Actions

    /// The coordinator owns the settings store, so pinning lives here rather
    /// than in a view reaching for global state.
    private func makeActions() -> DockActions {
        DockActions(
            activate: { [weak self] item in self?.activate(item) },
            togglePin: { [weak self] item in self?.togglePin(item) },
            reveal: DockCommands.reveal,
            hide: DockCommands.hide,
            quit: DockCommands.quit,
            drop: { [weak self] urls in self?.drop(urls) },
            move: { [weak self] identifier, before in self?.move(identifier, before: before) },
            hideOthers: DockCommands.hideOthers,
            emptyTrash: Trash.emptyViaFinder,
            trash: Trash.moveToTrash,
            showAllWindows: DockCommands.showAllWindows,
            raiseWindow: DockCommands.raiseWindow,
            openSetup: openSetup
        )
    }

    private func activate(_ item: DockItem) {
        switch item.kind {
        case .app(let identifier):
            AppActivator.activate(bundleIdentifier: identifier, whenActive: settings.settings.activeClickBehavior)
        case .file, .trash:
            DockCommands.open(item)
        case .spacer:
            return
        }
    }

    /// A local edit while mirroring would otherwise land in a list nothing
    /// reads. Editing forks: the mirrored lists become the custom ones, then
    /// the edit applies to them, and the Apps pane shows that the fork happened.
    private func forkFromMirrorIfNeeded() {
        guard settings.settings.mirrorSystemDock else { return }
        let mirrored = effectiveSettings
        settings.settings.mirrorSystemDock = false
        settings.settings.pinnedBundleIdentifiers = mirrored.pinnedBundleIdentifiers
        settings.settings.pinnedOthers = mirrored.pinnedOthers
    }

    /// "Keep in Dock" and "Remove from Dock", for whatever kind of tile asked.
    private func togglePin(_ item: DockItem) {
        forkFromMirrorIfNeeded()
        switch item.kind {
        case .app(let identifier):
            var pinned = settings.settings.pinnedBundleIdentifiers
            if let index = pinned.firstIndex(of: identifier) {
                pinned.remove(at: index)
            } else {
                pinned.append(identifier)
            }
            settings.settings.pinnedBundleIdentifiers = pinned
        case .file(let url):
            settings.settings.pinnedOthers.removeAll { $0 == url.absoluteString }
        case .trash:
            settings.settings.showTrash = false
        case .spacer(let ordinal):
            removeSpacer(ordinal: ordinal, from: item.section)
        }
    }

    private func removeSpacer(ordinal: Int, from section: DockItem.Section) {
        var list = section == .others ? settings.settings.pinnedOthers : settings.settings.pinnedBundleIdentifiers
        let spacers = list.indices.filter { list[$0] == DockItem.spacerIdentifier }
        guard ordinal < spacers.count else { return }
        list.remove(at: spacers[ordinal])

        if section == .others {
            settings.settings.pinnedOthers = list
        } else {
            settings.settings.pinnedBundleIdentifiers = list
        }
    }

    /// Apps dropped on a dock get pinned; anything else joins the section
    /// after the apps. A stray drag of nothing usable is ignored, not alerted.
    private func drop(_ urls: [URL]) {
        let apps = urls.filter { $0.pathExtension == "app" }.compactMap { Bundle(url: $0)?.bundleIdentifier }
        let others = urls.filter { $0.pathExtension != "app" }.map(\.absoluteString)
        guard !apps.isEmpty || !others.isEmpty else { return }

        forkFromMirrorIfNeeded()
        for identifier in apps where !settings.settings.pinnedBundleIdentifiers.contains(identifier) {
            settings.settings.pinnedBundleIdentifiers.append(identifier)
        }
        for entry in others where !settings.settings.pinnedOthers.contains(entry) {
            settings.settings.pinnedOthers.append(entry)
        }
    }

    /// A dragged app lands in front of the tile that was under the pointer,
    /// or at the end of the pinned run. A tile that was merely running becomes
    /// pinned by the act of being arranged, which is what the gesture implies.
    private func move(_ identifier: String, before target: DockItem?) {
        forkFromMirrorIfNeeded()
        var pinned = settings.settings.pinnedBundleIdentifiers
        pinned.removeAll { $0 == identifier }
        pinned.insert(identifier, at: target.flatMap { pinIndex(of: $0, in: pinned) } ?? pinned.endIndex)

        guard pinned != settings.settings.pinnedBundleIdentifiers else { return }
        settings.settings.pinnedBundleIdentifiers = pinned
    }

    /// Spacers share one sentinel, so one is found by counting.
    private func pinIndex(of item: DockItem, in pins: [String]) -> Int? {
        switch item.kind {
        case .app(let identifier):
            return pins.firstIndex(of: identifier)
        case .spacer(let ordinal):
            let spacers = pins.indices.filter { pins[$0] == DockItem.spacerIdentifier }
            return ordinal < spacers.count ? spacers[ordinal] : nil
        case .file, .trash:
            return nil
        }
    }

    /// A tile let go off its own dock: another display's dock under the
    /// pointer takes it, otherwise a pinned one is unpinned, the Dock's poof.
    private func dragReleased(
        _ item: DockItem,
        atScreenPoint point: CGPoint,
        from source: CGDirectDisplayID
    ) -> DragReleaseOutcome {
        for (identifier, controller) in controllers where identifier != source {
            guard let landing = controller.landing(atScreenPoint: point, for: item) else { continue }
            move(item.id, before: landing.before)
            return .moved
        }
        guard item.isPinned else { return .cancelled }
        togglePin(item)
        return .removed
    }

    private func closeControllers(notIn surviving: Set<CGDirectDisplayID>) {
        let departed = controllers.keys.filter { !surviving.contains($0) }
        for identifier in departed {
            controllers[identifier]?.close()
            controllers[identifier] = nil
        }
    }
}
