import CoreGraphics
import Testing

@testable import macdock

@Suite("Accessibility coordinate conversion")
struct CoordinatesTests {
    private let primaryHeight: CGFloat = 1169

    @Test("Converting a rect and back returns the original")
    func rectConversionIsItsOwnInverse() {
        let original = CGRect(x: 120, y: 340, width: 800, height: 600)

        let asAX = Coordinates.accessibilityRect(fromAppKit: original, primaryHeight: primaryHeight)
        let roundTripped = Coordinates.appKitRect(fromAccessibility: asAX, primaryHeight: primaryHeight)

        #expect(roundTripped == original)
    }

    @Test("A window at the top of the primary display has an Accessibility y of zero")
    func topOfPrimaryDisplayMapsToZero() {
        let fullHeightWindow = CGRect(x: 0, y: 0, width: 400, height: primaryHeight)
        let asAX = Coordinates.accessibilityRect(fromAppKit: fullHeightWindow, primaryHeight: primaryHeight)

        #expect(asAX.origin.y == 0)
    }

    @Test("The pivot is the primary display, not the display the window is on")
    func conversionPivotsOnPrimaryHeightOnly() {
        // A window on a taller secondary display that begins below the primary
        // display's baseline. Using the secondary's own height here would place
        // it hundreds of points away from where it belongs.
        let onSecondary = CGRect(x: 1800, y: -92, width: 600, height: 400)

        let asAX = Coordinates.accessibilityRect(fromAppKit: onSecondary, primaryHeight: primaryHeight)
        let backAgain = Coordinates.appKitRect(fromAccessibility: asAX, primaryHeight: primaryHeight)

        #expect(asAX.origin.y == primaryHeight - (-92) - 400)
        #expect(backAgain == onSecondary)
    }

    @Test("Point conversion round-trips")
    func pointConversionIsItsOwnInverse() {
        let original = CGPoint(x: 42, y: 300)

        let asAX = Coordinates.accessibilityPoint(fromAppKit: original, primaryHeight: primaryHeight)
        let roundTripped = Coordinates.appKitPoint(fromAccessibility: asAX, primaryHeight: primaryHeight)

        #expect(roundTripped == original)
    }
}
