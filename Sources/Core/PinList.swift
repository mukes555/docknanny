import Foundation

/// Edits to a pin list, as pure functions on the stored strings.
///
/// A pin list is bundle identifiers (or file URLs, in the section after the
/// apps) with ``DockItem/spacerIdentifier`` wherever there is a gap. Spacers
/// all share one sentinel, so one is found by counting, never by value. The
/// coordinator decides when an edit applies; what it does to the list is
/// decided here, where it can be tested without a display.
enum PinList {
    /// Adds the identifier if absent, removes it if present.
    static func toggling(_ identifier: String, in pins: [String]) -> [String] {
        var edited = pins
        if let index = edited.firstIndex(of: identifier) {
            edited.remove(at: index)
        } else {
            edited.append(identifier)
        }
        return edited
    }

    /// Puts the identifier in front of the target tile, or at the end for
    /// nil or for a target that is not itself pinned.
    static func moving(_ identifier: String, before target: DockItem?, in pins: [String]) -> [String] {
        var edited = pins
        edited.removeAll { $0 == identifier }
        let index = target.flatMap { self.index(of: $0, in: edited) } ?? edited.endIndex
        edited.insert(identifier, at: index)
        return edited
    }

    /// Appends whatever is not already present, keeping the order given.
    static func adding(_ entries: [String], to pins: [String]) -> [String] {
        var edited = pins
        for entry in entries where !edited.contains(entry) {
            edited.append(entry)
        }
        return edited
    }

    static func removingSpacer(ordinal: Int, from pins: [String]) -> [String] {
        let spacers = pins.indices.filter { pins[$0] == DockItem.spacerIdentifier }
        guard ordinal < spacers.count else { return pins }
        var edited = pins
        edited.remove(at: spacers[ordinal])
        return edited
    }

    /// Where a tile sits in the list: an app by identifier, a spacer by
    /// counting. Files and the Trash have no place in an apps list.
    static func index(of item: DockItem, in pins: [String]) -> Int? {
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
}
