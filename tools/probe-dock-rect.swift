#!/usr/bin/env swift
// Answers one question: will the window server let DockNanny reserve screen
// space the way the Dock does, so zoomed windows stop beside a DockNanny dock?
//
//   swift tools/probe-dock-rect.swift           read: the Dock's rect and each display's visible frame
//   swift tools/probe-dock-rect.swift try       set a test rect on a display without the Dock, report, restore
//   swift tools/probe-dock-rect.swift try-here  one display: set a rect on the edge opposite the Dock
//
// "try-here" answers a narrower question: does the window server take a
// rect from this process at all, and does the Dock's own exclusion survive
// alongside it (separate rects per process) or vanish (one rect)?
//
// Answered on macOS 26.5 with one display: the call is accepted from any
// process, and there is one rect. Setting ours removed the Dock's own
// exclusion on the same display. Whether the rect is also one across
// displays is what "try" with two displays still has to show.
//
// "try" changes window-server state for about two seconds and puts the Dock's
// own rect back before exiting, whatever happens. Run it with no windows
// zoomed, then look at the two "visible" lines: if the second differs from
// the first on the display without the Dock, the feature is possible. If the
// display WITH the Dock also changed, there is only one rect for the whole
// system and the feature cannot coexist with the real Dock.
import AppKit

typealias MainConnection = @convention(c) () -> Int32
// The orientation is a 64-bit integer. Passed as 32 bits, the upper half of
// the register carries garbage that the window server stores, and the Dock's
// exclusion comes back as a band on the wrong edge.
typealias GetRect = @convention(c) (Int32, UnsafeMutablePointer<CGRect>, UnsafeMutablePointer<Int>) -> Int32
typealias SetRect = @convention(c) (Int32, CGRect, Int) -> Int32

let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
func symbol<T>(_ name: String, as type: T.Type) -> T {
    guard let pointer = dlsym(skyLight, name) else { print("missing symbol \(name)"); exit(1) }
    return unsafeBitCast(pointer, to: type)
}
let connection = symbol("SLSMainConnectionID", as: MainConnection.self)()
let getRect = symbol("SLSGetDockRectWithOrientation", as: GetRect.self)
let setRect = symbol("SLSSetDockRectWithOrientation", as: SetRect.self)

func report(_ label: String) {
    // A fresh process, because NSScreen caches its frames until a screen
    // change notification, which this script never receives.
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    child.arguments = [CommandLine.arguments[0], "report", label]
    try? child.run()
    child.waitUntilExit()
}

var current = CGRect.zero
var orientation = 0
_ = getRect(connection, &current, &orientation)

if CommandLine.arguments.count > 2, CommandLine.arguments[1] == "report" {
    print("[\(CommandLine.arguments[2])] dock rect \(current) orientation \(orientation)")
    for screen in NSScreen.screens {
        print("    \(screen.localizedName): visible \(screen.visibleFrame)")
    }
    exit(0)
}

report("now")
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "read"
guard mode == "try" || mode == "try-here" else { exit(0) }

var count: UInt32 = 0
var displays = [CGDirectDisplayID](repeating: 0, count: 16)
CGGetActiveDisplayList(16, &displays, &count)
let active = displays.prefix(Int(count))

// Orientations are the Dock's own: 2 bottom, 3 left, 4 right.
let target: CGDirectDisplayID
let test: CGRect
let testOrientation: Int
if mode == "try" {
    // A display the Dock is not on, in the window server's top-left coordinates.
    guard let other = active.first(where: { !CGDisplayBounds($0).intersects(current) }) else {
        print("Every display has the Dock's rect on it; nothing to test. Use try-here for one display.")
        exit(0)
    }
    target = other
    let bounds = CGDisplayBounds(other)
    test = CGRect(x: bounds.minX, y: bounds.midY - 200, width: 74, height: 400)
    testOrientation = 3
} else {
    // The Dock's own display, on the right edge, away from wherever it is.
    guard let here = active.first(where: { CGDisplayBounds($0).intersects(current) }) ?? active.first else {
        print("No display."); exit(0)
    }
    target = here
    let bounds = CGDisplayBounds(here)
    test = CGRect(x: bounds.maxX - 74, y: bounds.midY - 200, width: 74, height: 400)
    testOrientation = 4
}

let status = setRect(connection, test, testOrientation)
print("set test rect \(test) on display \(target): status \(status)")
sleep(1)
report("with test rect")

let restored = setRect(connection, current, orientation)
print("restored the Dock's rect: status \(restored)")
sleep(1)
report("after restore")
