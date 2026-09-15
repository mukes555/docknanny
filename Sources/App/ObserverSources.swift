import ApplicationServices

/// The keeper's observers by process, and their removal from the run loop
/// when the keeper goes away. A source left on the main run loop would
/// deliver a notification into a callback whose pointer to the keeper is
/// dangling. A main-actor class cannot do this from its own deinit under
/// strict concurrency; this small box can, and it is released with its
/// owner.
final class ObserverSources {
    var byProcess: [pid_t: AXObserver] = [:]

    deinit {
        // The callbacks run on the main thread, so retiring their pointer to
        // the keeper is only safe there. The keeper lives on the main actor;
        // a release anywhere else is a bug worth stopping on.
        dispatchPrecondition(condition: .onQueue(.main))
        for observer in byProcess.values {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }
}
