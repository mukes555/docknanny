import CoreGraphics
import Testing

@testable import macdock

private func display(id: CGDirectDisplayID, primary: Bool = false) -> Display {
    Display(
        id: id,
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1040),
        backingScaleFactor: 2,
        isPrimary: primary,
        localizedName: "Display \(id)"
    )
}

@Suite("Per-display settings")
struct PerDisplayTests {
    @Test("A display with no override inherits every global value")
    func inheritanceIsTheDefault() {
        var settings = Settings()
        settings.edge = .left
        settings.tint = .teal

        let resolved = settings.resolved(for: display(id: 7))

        #expect(resolved.edge == .left)
        #expect(resolved.tint == .teal)
    }

    @Test("An override wins over the global value, field by field")
    func overridesWinIndependently() {
        var settings = Settings()
        settings.edge = .left
        settings.tint = .teal
        settings.setOverride(DisplayOverride(tint: .ember), forDisplay: 7)

        let resolved = settings.resolved(for: display(id: 7))

        #expect(resolved.tint == .ember)
        #expect(resolved.edge == .left, "untouched fields must still inherit")
    }

    /// The point of the whole per-display axis: this screen is for one kind of
    /// work and carries a different set of apps.
    @Test("A display can carry its own pinned apps")
    func perDisplayPinnedApps() {
        var settings = Settings()
        settings.pinnedBundleIdentifiers = ["com.apple.finder"]
        settings.setOverride(
            DisplayOverride(pinnedBundleIdentifiers: ["com.apple.mail", "com.apple.Safari"]),
            forDisplay: 3
        )

        #expect(settings.resolved(for: display(id: 3)).pinnedBundleIdentifiers
            == ["com.apple.mail", "com.apple.Safari"])
        #expect(settings.resolved(for: display(id: 9)).pinnedBundleIdentifiers
            == ["com.apple.finder"])
    }

    @Test("Auto-hide can be set for one screen without affecting the others")
    func autoHideIsPerDisplay() {
        var settings = Settings()
        settings.autoHide = false
        settings.setOverride(DisplayOverride(autoHide: true), forDisplay: 2)

        #expect(settings.resolved(for: display(id: 2)).autoHide)
        #expect(!settings.resolved(for: display(id: 5)).autoHide)
    }

    /// An override equal to the defaults is stored as nothing, so a user who
    /// changes a setting and changes it back does not leave a stale entry
    /// pinned to a monitor forever.
    @Test("Resetting an override removes it rather than storing an empty one")
    func defaultOverridesAreNotStored() {
        var settings = Settings()
        settings.setOverride(DisplayOverride(tint: .blue), forDisplay: 4)
        #expect(!settings.perDisplay.isEmpty)

        settings.setOverride(DisplayOverride(), forDisplay: 4)
        #expect(settings.perDisplay.isEmpty)
    }

    /// Keys used to be the session-assigned CGDirectDisplayID. Upgrading must
    /// not silently discard a user's per-display setup.
    @Test("A settings file written before stable keys is still read")
    func legacyNumericKeysAreStillHonoured() {
        var settings = Settings()
        settings.perDisplay = ["11": DisplayOverride(tint: .violet)]

        #expect(settings.resolved(for: display(id: 11)).tint == .violet)
    }

    @Test("Writing an override migrates the legacy key away")
    func writingMigratesTheKey() {
        var settings = Settings()
        settings.perDisplay = ["11": DisplayOverride(tint: .violet)]
        settings.setOverride(DisplayOverride(tint: .sand), forDisplay: 11)

        #expect(settings.perDisplay["11"] == nil)
        #expect(settings.resolved(for: display(id: 11)).tint == .sand)
    }

    @Test("The display with the system Dock is skipped by default, and only that one")
    func systemDockDisplayIsSkipped() {
        var settings = Settings()
        var withDock = display(id: 4)
        withDock.hasSystemDock = true

        #expect(!settings.resolved(for: withDock).isEnabled)
        #expect(settings.resolved(for: display(id: 5)).isEnabled)

        settings.skipSystemDockDisplay = false
        #expect(settings.resolved(for: withDock).isEnabled)

        // An explicit per-display choice beats the rule either way.
        settings.skipSystemDockDisplay = true
        settings.setOverride(DisplayOverride(isEnabled: true), forDisplay: 4)
        #expect(settings.resolved(for: withDock).isEnabled)
    }
}
