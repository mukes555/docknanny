import Carbon.HIToolbox

/// Global keyboard shortcuts through Carbon's hot key API.
///
/// This is the one way to get a system-wide shortcut without Accessibility
/// or Input Monitoring: the window server delivers the key to the registering
/// process and swallows it, so the app in front never sees it. It also
/// reports a conflict at registration time instead of silently losing the
/// race, which is what an event tap would do.
@MainActor
final class HotkeyCenter {
    struct Binding {
        let role: HotkeyRole
        let modifiers: HotkeyModifiers
        let action: () -> Void
    }

    /// Roles whose registration was refused. Carbon does not report another
    /// process holding the same combination (both simply receive it), so this
    /// only ever holds genuine failures.
    private(set) var conflicts: Set<HotkeyRole> = []

    private var registered: [UInt32: Binding] = [:]
    private let registrations = HotkeyRegistrations()
    /// Hot keys currently held down. Carbon repeats the pressed event at the
    /// keyboard's repeat rate for as long as the keys are held, and one press
    /// is one action: a held toggle must not flicker.
    private var held: Set<UInt32> = []
    private var nextIdentifier: UInt32 = 1

    /// "dnny", so hot key events can be told apart from anyone else's.
    private static let signature: OSType = 0x646E_6E79

    init() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.dispatch,
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &registrations.handler
        )
        if status != noErr {
            Log.app.error("Hot key handler refused: \(status, privacy: .public)")
        }
    }

    /// Replaces every binding. Re-registering from scratch is simpler than
    /// diffing and costs nothing at the rate settings change.
    func replaceAll(with bindings: [Binding]) {
        for reference in registrations.hotKeys.values {
            UnregisterEventHotKey(reference)
        }
        registrations.hotKeys.removeAll()
        registered.removeAll()
        held.removeAll()
        conflicts.removeAll()

        for binding in bindings {
            register(binding)
        }
        Log.app.info("Registered \(self.registered.count, privacy: .public) hot key(s)")
    }

    private func register(_ binding: Binding) {
        let identifier = nextIdentifier
        nextIdentifier += 1

        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.role.keyCode,
            binding.modifiers.carbonFlags,
            EventHotKeyID(signature: Self.signature, id: identifier),
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            conflicts.insert(binding.role)
            Log.app.notice("Hot key \(binding.role.keyLabel, privacy: .public) is taken: \(status, privacy: .public)")
            return
        }
        registrations.hotKeys[identifier] = reference
        registered[identifier] = binding
    }

    /// Carbon calls this on the main thread, from the run loop that also
    /// drives AppKit, so hopping onto the main actor is a formality.
    private static let dispatch: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }

        var hotKey = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKey
        )
        guard status == noErr, hotKey.signature == signature else { return OSStatus(eventNotHandledErr) }

        let isRelease = GetEventKind(event) == UInt32(kEventHotKeyReleased)
        let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
        MainActor.assumeIsolated {
            if isRelease {
                center.held.remove(hotKey.id)
            } else if center.held.insert(hotKey.id).inserted {
                center.registered[hotKey.id]?.action()
            }
        }
        return noErr
    }
}

/// What Carbon hands back, given back when the centre goes away: the event
/// handler, whose callback carries an unretained pointer to the centre, and
/// every hot key, which would otherwise stay swallowed system-wide with no
/// one listening. A main-actor class cannot do this from its own deinit
/// under strict concurrency; this small box can, and it is released with
/// its owner.
final class HotkeyRegistrations {
    var handler: EventHandlerRef?
    var hotKeys: [UInt32: EventHotKeyRef] = [:]

    deinit {
        for reference in hotKeys.values {
            UnregisterEventHotKey(reference)
        }
        if let handler {
            RemoveEventHandler(handler)
        }
    }
}
