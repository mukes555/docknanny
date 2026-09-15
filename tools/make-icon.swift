// Draws DockNanny's app icon and menu bar mark, and writes the icon ladder.
//
// The mark is two displays, each with its own lime dock bar, on deep forest:
// the proposition drawn literally (docs/BRANDING.md). The geometry is shared
// with the design canvas the direction was chosen on, in a 1024-point space
// with y down, so the two renderings stay identical.
//
//   swift tools/make-icon.swift <output-directory>

import AppKit
import CoreGraphics
import Foundation

let space = CGColorSpaceCreateDeviceRGB()
let groundTop = CGColor(red: 0.165, green: 0.302, blue: 0.165, alpha: 1)
let groundBottom = CGColor(red: 0.063, green: 0.118, blue: 0.078, alpha: 1)
let screen = CGColor(red: 0.059, green: 0.118, blue: 0.075, alpha: 1)
let limeLight = CGColor(red: 0.651, green: 0.839, blue: 0.361, alpha: 1)
let limeDeep = CGColor(red: 0.490, green: 0.710, blue: 0.204, alpha: 1)

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
func fillLime(_ path: CGPath, in context: CGContext, size: CGFloat) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    if let lime = gradient(limeLight, limeDeep) {
        context.drawLinearGradient(lime, start: .zero, end: CGPoint(x: size, y: size), options: [])
    }
    context.restoreGState()
}

/// Strokes a path with the lime gradient. Strokes never drop below a pixel
/// and a half: at 16 points the true width would vanish.
func strokeLime(_ path: CGPath, width: CGFloat, in context: CGContext, size: CGFloat, scale: CGFloat) {
    context.saveGState()
    context.addPath(path)
    context.setLineWidth(max(width * scale, 1.5))
    context.replacePathWithStrokedPath()
    context.clip()
    if let lime = gradient(limeLight, limeDeep) {
        context.drawLinearGradient(lime, start: .zero, end: CGPoint(x: size, y: size), options: [])
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
    let glossTop = CGColor(red: 1, green: 1, blue: 1, alpha: 0.2)
    let glossEnd = CGColor(red: 1, green: 1, blue: 1, alpha: 0)
    if let gloss = gradient(glossTop, glossEnd) {
        context.drawLinearGradient(gloss, start: .zero, end: CGPoint(x: 0, y: size * 0.55), options: [])
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
        strokeLime(display, width: 34, in: context, size: size, scale: scale)
        fillLime(bar, in: context, size: size)
    }

    // The near display's stand.
    fillLime(rounded(340, 716, 114, 34, 17, scale), in: context, size: size)
    context.saveGState()
    context.setAlpha(0.7)
    fillLime(rounded(256, 756, 282, 34, 17, scale), in: context, size: size)
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
