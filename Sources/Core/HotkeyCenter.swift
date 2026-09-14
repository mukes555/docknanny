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

    private var registered: [UInt32: (reference: EventHotKeyRef, binding: Binding)] = [:]
    private var handler: EventHandlerRef?
    private var nextIdentifier: UInt32 = 1

    /// "mdck", so hot key events can be told apart from anyone else's.
    private static let signature: OSType = 0x6D64_636B

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.dispatch,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        if status != noErr {
            Log.app.error("Hot key handler refused: \(status, privacy: .public)")
        }
    }

    /// Replaces every binding. Re-registering from scratch is simpler than
    /// diffing and costs nothing at the rate settings change.
    func replaceAll(with bindings: [Binding]) {
        for (_, entry) in registered {
            UnregisterEventHotKey(entry.reference)
        }
        registered.removeAll()
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
        registered[identifier] = (reference, binding)
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

        let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
        MainActor.assumeIsolated {
            center.registered[hotKey.id]?.binding.action()
        }
        return noErr
    }
}
