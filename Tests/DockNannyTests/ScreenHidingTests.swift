import CoreGraphics
import Testing

@testable import DockNanny

@Suite("Hiding an app on one screen")
struct ScreenHidingTests {
    /// The arrangement on a real two-display desk: the built-in display is the
    /// primary at the origin, the external one sits to its right and hangs
    /// lower, so its frame starts at a negative y.
    private let builtIn = CGRect(x: 0, y: 0, width: 1800, height: 1169)
    private let external = CGRect(x: 1800, y: -92, width: 2560, height: 1440)

    private func window(_ frame: CGRect, minimized: Bool = false) -> ScreenHiding.Window {
        ScreenHiding.Window(frame: frame, isMinimized: minimized)
    }

    @Test("What is visible on this screen is folded away, and nothing else is")
    func foldsAwayOnlyThisScreen() {
        let windows = [
            window(CGRect(x: 100, y: 100, width: 800, height: 600)),
            window(CGRect(x: 2000, y: 100, width: 1200, height: 900)),
            window(CGRect(x: 2400, y: 400, width: 900, height: 700))
        ]

        #expect(ScreenHiding.action(for: windows, onScreen: external) == .minimize([1, 2]))
        #expect(ScreenHiding.action(for: windows, onScreen: builtIn) == .minimize([0]))
    }

    @Test("With nothing left to fold away, the next click brings this screen's windows back")
    func bringsBackWhatWasFoldedAwayHere() {
        let windows = [
            window(CGRect(x: 100, y: 100, width: 800, height: 600)),
            window(CGRect(x: 2000, y: 100, width: 1200, height: 900), minimized: true),
            window(CGRect(x: 2400, y: 400, width: 900, height: 700), minimized: true)
        ]

        #expect(ScreenHiding.action(for: windows, onScreen: external) == .restore([1, 2]))
        // The other screen still has something to fold away, and is untouched
        // by what happened here.
        #expect(ScreenHiding.action(for: windows, onScreen: builtIn) == .minimize([0]))
    }

    @Test("A window straddling two screens belongs to the one it mostly sits on")
    func straddlingWindowBelongsToOneScreen() {
        // Mostly on the external display: its middle is past the boundary.
        let straddling = [window(CGRect(x: 1500, y: 100, width: 1000, height: 700))]

        #expect(ScreenHiding.action(for: straddling, onScreen: external) == .minimize([0]))
        #expect(ScreenHiding.action(for: straddling, onScreen: builtIn) == .nothing)
    }

    @Test("A screen with nothing on it has nothing to do")
    func emptyScreenDoesNothing() {
        let elsewhere = [window(CGRect(x: 100, y: 100, width: 800, height: 600))]

        #expect(ScreenHiding.action(for: elsewhere, onScreen: external) == .nothing)
        #expect(ScreenHiding.action(for: [], onScreen: builtIn) == .nothing)
    }

    @Test("Showing wins over hiding: one window still visible here is folded away first")
    func visibleWindowsGoFirst() {
        let windows = [
            window(CGRect(x: 2000, y: 100, width: 1200, height: 900), minimized: true),
            window(CGRect(x: 2400, y: 400, width: 900, height: 700))
        ]

        #expect(ScreenHiding.action(for: windows, onScreen: external) == .minimize([1]))
    }
}

@Suite("Where a window is, while it is folded away")
@MainActor
struct FoldedWindowPositionTests {
    private let real = CGRect(x: 195, y: 638, width: 673, height: 439)
    /// What the window server reports for a window mid-fold: its thumbnail in
    /// the Dock, which is on whichever screen the Dock happens to be.
    private let thumbnail = CGRect(x: 23, y: 250, width: 177, height: 85)

    @Test("A folded window is where its app says, not where its thumbnail is")
    func foldedWindowTrustsTheApp() {
        #expect(ScreenHider.position(ofMinimized: true, server: thumbnail, app: real) == real)
        // With nothing from the app, the thumbnail is better than losing the window.
        #expect(ScreenHider.position(ofMinimized: true, server: thumbnail, app: nil) == thumbnail)
    }

    @Test("A window on screen is where the window server says, whatever its app claims")
    func visibleWindowTrustsTheWindowServer() {
        let claimed = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(ScreenHider.position(ofMinimized: false, server: real, app: claimed) == real)
        #expect(ScreenHider.position(ofMinimized: false, server: nil, app: claimed) == claimed)
    }

    @Test("A window neither source can place belongs to no screen")
    func unplaceableWindowIsLeftOut() {
        #expect(ScreenHider.position(ofMinimized: true, server: nil, app: nil) == nil)
        #expect(ScreenHider.position(ofMinimized: false, server: nil, app: nil) == nil)
    }
}
