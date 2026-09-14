/// Owns a long-running task and cancels it when the owner goes away.
///
/// A polling loop that captures its owner weakly would otherwise outlive the
/// owner, waking every interval to find nothing to do. A main-actor class
/// cannot cancel from its own deinit under strict concurrency (deinit is not
/// isolated), but this small box can, and it is released with its owner.
final class TaskBox {
    var task: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }

    deinit {
        task?.cancel()
    }
}
