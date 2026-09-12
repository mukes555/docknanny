import ApplicationServices
import CoreGraphics
import Foundation

// Private Apple SPI signatures. These are not public API and Apple is free to
// remove them in any release, which is precisely what this spike measures.

/// Connection to the window server for the current process.
typealias CGSMainConnectionIDFunction = @convention(c) () -> Int32

/// SkyLight id of the Mission Control space currently active on the focused display.
typealias CGSGetActiveSpaceFunction = @convention(c) (Int32) -> UInt64

/// Ordered per-display space list. Each element carries a "Display Identifier"
/// and an ordered "Spaces" array, which is the only route to per-display
/// (rather than global) space awareness.
typealias CGSCopyManagedDisplaySpacesFunction = @convention(c) (Int32) -> Unmanaged<CFArray>?

/// The window server's own id for an accessibility window element. Preferred
/// over matching on window titles, which collide whenever two documents share
/// a name, and over kAXWindowNumber, which some apps fill with private values.
typealias AXUIElementGetWindowFunction =
    @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

/// Private symbols resolved at runtime.
///
/// Every lookup goes through `dlsym` rather than `@_silgen_name` link-time
/// binding. A symbol Apple has deleted then surfaces here as `nil`, which the
/// caller can degrade around, instead of aborting the process during dyld
/// startup before any of our code runs.
struct SystemSymbols: @unchecked Sendable {
    let mainConnectionID: CGSMainConnectionIDFunction?
    let activeSpace: CGSGetActiveSpaceFunction?
    let managedDisplaySpaces: CGSCopyManagedDisplaySpacesFunction?
    let windowIDForElement: AXUIElementGetWindowFunction?

    static let resolved = SystemSymbols()

    /// Names of the symbols that failed to resolve, for reporting.
    var missing: [String] {
        var names: [String] = []
        if mainConnectionID == nil { names.append("CGSMainConnectionID") }
        if activeSpace == nil { names.append("CGSGetActiveSpace") }
        if managedDisplaySpaces == nil { names.append("CGSCopyManagedDisplaySpaces") }
        if windowIDForElement == nil { names.append("_AXUIElementGetWindow") }
        return names
    }

    private init() {
        let skyLight = dlopen(Self.skyLightPath, RTLD_LAZY)

        mainConnectionID = Self.load(skyLight, "CGSMainConnectionID",
                                     as: CGSMainConnectionIDFunction.self)
        activeSpace = Self.load(skyLight, "CGSGetActiveSpace",
                                as: CGSGetActiveSpaceFunction.self)
        managedDisplaySpaces = Self.load(skyLight, "CGSCopyManagedDisplaySpaces",
                                         as: CGSCopyManagedDisplaySpacesFunction.self)

        // Lives in HIServices, already loaded via ApplicationServices, so the
        // default search scope finds it without an explicit dlopen.
        windowIDForElement = Self.load(nil, "_AXUIElementGetWindow",
                                       as: AXUIElementGetWindowFunction.self)
    }

    private static let skyLightPath =
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"

    /// Searches the given image first, then every image already loaded into
    /// the process.
    private static func load<Function>(
        _ handle: UnsafeMutableRawPointer?,
        _ name: String,
        as type: Function.Type
    ) -> Function? {
        guard let pointer = symbol(handle, named: name) else { return nil }
        return unsafeBitCast(pointer, to: Function.self)
    }

    private static func symbol(
        _ handle: UnsafeMutableRawPointer?,
        named name: String
    ) -> UnsafeMutableRawPointer? {
        if let handle, let found = dlsym(handle, name) {
            return found
        }
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        return dlsym(rtldDefault, name)
    }
}
