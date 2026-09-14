#!/usr/bin/env swift
// Answers one question: will the window server let macdock reserve screen
// space the way the Dock does, so zoomed windows stop beside a macdock dock?
//
//   swift tools/probe-dock-rect.swift        read: the Dock's rect and each display's visible frame
//   swift tools/probe-dock-rect.swift try    set a test rect on a display without the Dock, report, restore
//
// "try" changes window-server state for about two seconds and puts the Dock's
// own rect back before exiting, whatever happens. Run it with no windows
// zoomed, then look at the two "visible" lines: if the second differs from
// the first on the display without the Dock, the feature is possible. If the
// display WITH the Dock also changed, there is only one rect for the whole
// system and the feature cannot coexist with the real Dock.
import AppKit

typealias MainConnection = @convention(c) () -> Int32
typealias GetRect = @convention(c) (Int32, UnsafeMutablePointer<CGRect>, UnsafeMutablePointer<Int32>) -> Int32
typealias SetRect = @convention(c) (Int32, CGRect, Int32) -> Int32

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
var orientation: Int32 = 0
_ = getRect(connection, &current, &orientation)

if CommandLine.arguments.count > 2, CommandLine.arguments[1] == "report" {
    print("[\(CommandLine.arguments[2])] dock rect \(current) orientation \(orientation)")
    for screen in NSScreen.screens {
        print("    \(screen.localizedName): visible \(screen.visibleFrame)")
    }
    exit(0)
}

report("now")
guard CommandLine.arguments.count > 1, CommandLine.arguments[1] == "try" else { exit(0) }

// A display the Dock is not on, in the window server's top-left coordinates.
var count: UInt32 = 0
var displays = [CGDirectDisplayID](repeating: 0, count: 16)
CGGetActiveDisplayList(16, &displays, &count)
guard let other = displays.prefix(Int(count)).first(where: { !CGDisplayBounds($0).intersects(current) }) else {
    print("Every display has the Dock's rect on it; nothing to test.")
    exit(0)
}
let bounds = CGDisplayBounds(other)
let test = CGRect(x: bounds.minX, y: bounds.midY - 200, width: 74, height: 400)
let leftOrientation: Int32 = 3

let status = setRect(connection, test, leftOrientation)
print("set test rect \(test) on display \(other): status \(status)")
sleep(1)
report("with test rect")

let restored = setRect(connection, current, orientation)
print("restored the Dock's rect: status \(restored)")
sleep(1)
report("after restore")
