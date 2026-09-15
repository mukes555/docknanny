// Draws DockNanny's app icon and menu bar mark, and writes the icon ladder.
//
// The mark is two displays, each with its own dock bar, in lime on a near
// black ground: the proposition drawn literally (docs/BRANDING.md). The
// geometry is shared with the design canvas the direction was chosen on and
// with BrandIconMark in the app, in a 1024-point space with y down, so every
// rendering stays identical.
//
//   swift tools/make-icon.swift <output-directory>

import AppKit
import CoreGraphics
import Foundation

let space = CGColorSpaceCreateDeviceRGB()
// Black and green: a deep olive to near-black ground, the glyph in brand
// lime #C0DD71 (a touch lighter at the top-left, a touch deeper at the
// bottom-right, so it reads as lit), and near-black screens.
let groundTop = CGColor(red: 0.122, green: 0.165, blue: 0.086, alpha: 1)      // #1F2A16
let groundBottom = CGColor(red: 0.047, green: 0.063, blue: 0.039, alpha: 1)   // #0C100A
let screen = CGColor(red: 0.055, green: 0.078, blue: 0.031, alpha: 1)         // #0E1408
let glyphLight = CGColor(red: 0.812, green: 0.910, blue: 0.545, alpha: 1)     // #CFE88B
let glyphDeep = CGColor(red: 0.702, green: 0.827, blue: 0.376, alpha: 1)      // #B3D360

func gradient(_ from: CGColor, _ to: CGColor) -> CGGradient? {
    CGGradient(colorsSpace: space, colors: [from, to] as CFArray, locations: [0, 1])
}

func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ scale: CGFloat) -> CGPath {
    CGPath(
        roundedRect: CGRect(x: x * scale, y: y * scale, width: w * scale, height: h * scale),
        cornerWidth: r * scale, cornerHeight: r * scale, transform: nil
    )
}

/// Fills a path with the lime gradient, top-left to bottom-right.
func fillGlyph(_ path: CGPath, in context: CGContext, size: CGFloat) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    if let glyph = gradient(glyphLight, glyphDeep) {
        context.drawLinearGradient(glyph, start: .zero, end: CGPoint(x: size, y: size), options: [])
    }
    context.restoreGState()
}

/// Strokes a path with the lime gradient. Strokes never drop below a pixel
/// and a half: at 16 points the true width would vanish.
func strokeGlyph(_ path: CGPath, width: CGFloat, in context: CGContext, size: CGFloat, scale: CGFloat) {
    context.saveGState()
    context.addPath(path)
    context.setLineWidth(max(width * scale, 1.5))
    context.replacePathWithStrokedPath()
    context.clip()
    if let glyph = gradient(glyphLight, glyphDeep) {
        context.drawLinearGradient(glyph, start: .zero, end: CGPoint(x: size, y: size), options: [])
    }
    context.restoreGState()
}

/// Draws the icon at `size` pixels. Coordinates match the canvas: y down.
func drawIcon(size: CGFloat) -> CGImage? {
    let scale = size / 1024
    guard let context = CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)

    // The macOS squircle ground: a diagonal forest gradient, a gloss across
    // the top half, a faint rim.
    let squircle = rounded(0, 0, 1024, 1024, 229, scale)
    context.saveGState()
    context.addPath(squircle)
    context.clip()
    if let ground = gradient(groundTop, groundBottom) {
        context.drawLinearGradient(ground, start: .zero, end: CGPoint(x: size, y: size), options: [])
    }
    let glossTop = CGColor(red: 1, green: 1, blue: 1, alpha: 0.16)
    let glossEnd = CGColor(red: 1, green: 1, blue: 1, alpha: 0)
    if let gloss = gradient(glossTop, glossEnd) {
        context.drawLinearGradient(gloss, start: .zero, end: CGPoint(x: 0, y: size * 0.6), options: [])
    }
    context.restoreGState()

    context.addPath(rounded(6, 6, 1012, 1012, 225, scale))
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
    context.setLineWidth(max(10 * scale, 1))
    context.strokePath()

    // The far display, then the near one over it, each with its dock bar.
    for (display, bar) in [
        (rounded(392, 236, 470, 330, 54, scale), rounded(446, 474, 362, 52, 26, scale)),
        (rounded(162, 372, 470, 330, 54, scale), rounded(216, 610, 362, 52, 26, scale))
    ] {
        context.addPath(display)
        context.setFillColor(screen)
        context.fillPath()
        strokeGlyph(display, width: 34, in: context, size: size, scale: scale)
        fillGlyph(bar, in: context, size: size)
    }

    // The near display's stand.
    fillGlyph(rounded(340, 716, 114, 34, 17, scale), in: context, size: size)
    context.saveGState()
    context.setAlpha(0.75)
    fillGlyph(rounded(256, 756, 282, 34, 17, scale), in: context, size: size)
    context.restoreGState()

    return context.makeImage()
}

/// The menu bar mark: the two displays reduced to outlines, 20 by 14 points.
///
/// A template image is alpha only, so this is flat black and macOS recolours
/// it for light, dark and tinted menu bars. The near display knocks a hole in
/// the far one, which is what keeps them two shapes at 14 points.
func drawMenuBarMark(scaleFactor: CGFloat) -> CGImage? {
    let width = 20 * scaleFactor
    let height = 14 * scaleFactor
    let scale = scaleFactor / 10  // the canvas mark is drawn in a 200 by 140 space
    guard let context = CGContext(
        data: nil, width: Int(width), height: Int(height),
        bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.setShouldAntialias(true)
    context.translateBy(x: 0, y: height)
    context.scaleBy(x: 1, y: -1)

    let ink = CGColor(gray: 0, alpha: 1)
    let stroke = max(14 * scale, 1.2)
    context.setStrokeColor(ink)
    context.setFillColor(ink)
    context.setLineWidth(stroke)

    context.addPath(rounded(70, 16, 118, 80, 14, scale))
    context.strokePath()

    // The near display: filled, then its interior cleared to transparent.
    let near = rounded(12, 46, 118, 80, 14, scale)
    context.addPath(near)
    context.setLineWidth(stroke)
    context.replacePathWithStrokedPath()
    context.addPath(near)
    context.fillPath()
    context.saveGState()
    context.setBlendMode(.clear)
    context.addPath(rounded(12 + 7, 46 + 7, 118 - 14, 80 - 14, 8, scale))
    context.fillPath()
    context.restoreGState()

    context.addPath(rounded(34, 94, 74, 12, 6, scale))
    context.fillPath()

    return context.makeImage()
}

func write(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}

let outputDirectory = CommandLine.arguments.count > 1
    ? URL(filePath: CommandLine.arguments[1])
    : URL(filePath: FileManager.default.currentDirectoryPath)

let iconset = outputDirectory.appending(path: "DockNanny.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// The ladder macOS expects inside an .iconset.
let rungs: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for rung in rungs {
    guard let image = drawIcon(size: rung.pixels) else { continue }
    try write(image, to: iconset.appending(path: "\(rung.name).png"))
}
if let composite = drawIcon(size: 1024) {
    try write(composite, to: outputDirectory.appending(path: "icon-1024.png"))
}

for (name, factor) in [("menubar", CGFloat(1)), ("menubar@2x", 2), ("menubar@3x", 3)] {
    guard let image = drawMenuBarMark(scaleFactor: factor) else { continue }
    try write(image, to: outputDirectory.appending(path: "\(name).png"))
}

print("wrote \(rungs.count) rungs, the menu bar mark and the composite to \(outputDirectory.path)")
