import CoreGraphics
import Foundation
import Testing

@testable import DockNanny

@Suite("Opening an app on the screen you clicked")
struct NewWindowPlacementTests {
    /// The external screen on a real desk, hanging below the primary one, so
    /// its usable area starts at a negative y.
    private let external = CGRect(x: 1800, y: -92, width: 2560, height: 1440)

    @Test("A window that fits keeps its size and lands in the middle of the clicked screen")
    func fittingWindowIsCentred() {
        let placed = NewWindowPlacer.centred(size: CGSize(width: 1200, height: 800), in: external)

        #expect(placed.size == CGSize(width: 1200, height: 800))
        #expect(placed.midX == external.midX)
        #expect(placed.midY == external.midY)
        #expect(external.contains(placed))
    }

    @Test("A window bigger than the clicked screen is shrunk to fit it, never spilling off")
    func oversizedWindowIsShrunkToFit() {
        let placed = NewWindowPlacer.centred(size: CGSize(width: 3000, height: 2000), in: external)

        #expect(placed == external)
    }

    @Test("Only the side that does not fit is shrunk")
    func onlyTheOversizedSideShrinks() {
        let placed = NewWindowPlacer.centred(size: CGSize(width: 1000, height: 1600), in: external)

        #expect(placed.width == 1000)
        #expect(placed.height == external.height)
        #expect(external.contains(placed))
    }
}

@Suite("Click defaults")
struct ClickDefaultsTests {
    @Test("A fresh install hides on the clicked screen and opens apps there")
    func freshInstallDefaults() {
        let settings = Settings()

        #expect(settings.activeClickBehavior == .hideOnThisScreen)
        #expect(settings.opensAppsOnClickedScreen)
    }

    @Test("A settings file from before the option existed opens apps on the clicked screen")
    func existingFileGainsTheNewBehaviour() throws {
        let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"activeClickBehavior": "hide"}"#.utf8))

        #expect(settings.opensAppsOnClickedScreen)
        // What the person chose before is kept; only the missing key takes the default.
        #expect(settings.activeClickBehavior == .hide)
    }

    @Test("Turning it off is remembered")
    func turningItOffIsKept() throws {
        let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"opensAppsOnClickedScreen": false}"#.utf8))

        #expect(!settings.opensAppsOnClickedScreen)
    }
}
