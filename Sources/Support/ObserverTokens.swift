import Foundation

/// Holds NotificationCenter observer tokens and unregisters them when the
/// owning object goes away.
///
/// Block-based observers outlive their observer unless explicitly removed, but
/// a `@MainActor` type's `deinit` is nonisolated in Swift 6 and cannot reach
/// isolated stored properties. Parking the tokens in a plain class solves both
/// halves: this type's own deinit is free to clean up, and the owner needs no
/// deinit at all.
///
/// Owners must capture `self` weakly inside the observer block. A strong
/// capture keeps the notification centre holding the owner alive, so neither
/// this object nor its cleanup ever runs.
final class ObserverTokens {
    private let center: NotificationCenter
    private var tokens: [NSObjectProtocol] = []

    init(center: NotificationCenter) {
        self.center = center
    }

    func add(_ token: NSObjectProtocol) {
        tokens.append(token)
    }

    deinit {
        for token in tokens {
            center.removeObserver(token)
        }
    }
}
