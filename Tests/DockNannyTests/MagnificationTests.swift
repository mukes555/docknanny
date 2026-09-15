import CoreGraphics
import Testing

@testable import DockNanny

@Suite("Magnification curve")
struct MagnificationTests {
    private let radius: CGFloat = 120
    private let peak: CGFloat = 1.6

    @Test("A tile directly under the pointer reaches full scale")
    func peakAtZeroDistance() {
        let scale = Magnification.scale(distance: 0, influenceRadius: radius, maximumScale: peak)
        #expect(scale == peak)
    }

    @Test("A tile beyond the influence radius is untouched")
    func noEffectOutsideRadius() {
        let atEdge = Magnification.scale(distance: radius, influenceRadius: radius, maximumScale: peak)
        let beyond = Magnification.scale(distance: radius * 3, influenceRadius: radius, maximumScale: peak)

        #expect(atEdge == 1)
        #expect(beyond == 1)
    }

    @Test("Scale falls off monotonically with distance")
    func falloffIsMonotonic() {
        let samples = stride(from: CGFloat(0), through: radius, by: 10).map {
            Magnification.scale(distance: $0, influenceRadius: radius, maximumScale: peak)
        }

        for (nearer, further) in zip(samples, samples.dropFirst()) {
            #expect(nearer >= further)
        }
    }

    @Test("A zero radius disables the effect rather than dividing by zero")
    func zeroRadiusIsSafe() {
        let scale = Magnification.scale(distance: 0, influenceRadius: 0, maximumScale: peak)
        #expect(scale == 1)
    }

    @Test("Negative distances cannot push scale above the maximum")
    func scaleIsClamped() {
        let scale = Magnification.scale(distance: -50, influenceRadius: radius, maximumScale: peak)
        #expect(scale <= peak)
    }
}
