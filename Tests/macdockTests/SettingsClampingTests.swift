import Foundation
import Testing

@testable import macdock

@Suite("Settings clamping")
struct SettingsClampingTests {
    private let display = Display(
        id: 1,
        frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
        visibleFrame: CGRect(x: 0, y: 0, width: 1800, height: 1130),
        backingScaleFactor: 2,
        isPrimary: true,
        localizedName: "Built-in"
    )

    @Test("Absurd geometry from a hand-edited file is brought back into range")
    func absurdValuesAreClamped() {
        var settings = Settings()
        settings.iconSize = 100_000
        settings.itemSpacing = -50
        settings.margin = 9_999
        settings.magnificationScale = 40

        let resolved = settings.resolved(for: display)

        #expect(resolved.iconSize == CGFloat(Settings.Limits.iconSize.upperBound))
        #expect(resolved.itemSpacing == CGFloat(Settings.Limits.itemSpacing.lowerBound))
        #expect(resolved.margin == CGFloat(Settings.Limits.margin.upperBound))
        #expect(resolved.magnificationScale == CGFloat(Settings.Limits.scale.upperBound))
    }

    /// min(max(.nan, low), high) is .nan in Swift, and a NaN reaching
    /// NSPanel.setFrame is unrecoverable, so this is the load-bearing case.
    @Test("Non-finite values become the low bound rather than propagating")
    func nonFiniteValuesAreNeutralised() {
        var settings = Settings()
        settings.iconSize = .nan
        settings.margin = .infinity
        settings.chromeOpacity = -.infinity

        let resolved = settings.resolved(for: display)

        #expect(resolved.iconSize.isFinite)
        #expect(resolved.margin.isFinite)
        #expect(resolved.chromeOpacity.isFinite)
    }

    @Test("A per-display icon size override is clamped too")
    func overridesAreClampedAsWell() {
        var settings = Settings()
        settings.setOverride(DisplayOverride(iconSize: 500_000), forDisplay: display.id)

        let resolved = settings.resolved(for: display)

        #expect(resolved.iconSize == CGFloat(Settings.Limits.iconSize.upperBound))
    }

    @Test("Values already in range are left exactly alone")
    func validValuesArePreserved() {
        var settings = Settings()
        settings.iconSize = 52
        settings.margin = 11

        let resolved = settings.resolved(for: display)

        #expect(resolved.iconSize == 52)
        #expect(resolved.margin == 11)
    }
}
