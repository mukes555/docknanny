// Draws macdock's mark and writes the icon ladder.
//
// The mark is the glasses, not the quokka: at 16pt an animal is mush while the
// frames stay legible (docs/BRANDING.md). This is a placeholder for the
// generated mascot artwork, built from the same brand geometry so the two do
// not look like different products when the real assets land.
//
//   swift tools/make-icon.swift <output-directory>

import AppKit
import CoreGraphics
import Foundation

let forest = CGColor(red: 0.118, green: 0.227, blue: 0.118, alpha: 1)
let lime = CGColor(red: 0.545, green: 0.773, blue: 0.247, alpha: 1)
let frame = CGColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)

/// Draws the mark at `size` points into a new bitmap context.
func drawMark(size: CGFloat, includeGround: Bool) -> CGImage? {
    let scale = size / 1024
    guard let context = CGContext(
        data: nil,
        width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    if includeGround {
        // Rounded-square ground, then the lime disc the mascot art also sits on.
        let inset = 24 * scale
        let ground = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let rounded = CGPath(
            roundedRect: ground,
            cornerWidth: 230 * scale, cornerHeight: 230 * scale,
            transform: nil
        )
        context.addPath(rounded)
        context.setFillColor(forest)
        context.fillPath()

        context.setFillColor(lime)
        let radius = 372 * scale
        context.fillEllipse(in: CGRect(
            x: size / 2 - radius, y: size / 2 - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    drawGlasses(in: context, size: size, scale: scale)
    return context.makeImage()
}

func drawGlasses(in context: CGContext, size: CGFloat, scale: CGFloat) {
    let lensWidth = 268 * scale
    let lensHeight = 212 * scale
    let bridge = 56 * scale
    let stroke = 40 * scale
    let corner = 56 * scale

    let totalWidth = lensWidth * 2 + bridge
    let left = size / 2 - totalWidth / 2
    let top = size / 2 - lensHeight / 2

    let lenses = [
        CGRect(x: left, y: top, width: lensWidth, height: lensHeight),
        CGRect(x: left + lensWidth + bridge, y: top, width: lensWidth, height: lensHeight)
    ]

    // Temple arms first, so the frames overlap their ends cleanly.
    context.setStrokeColor(frame)
    context.setLineWidth(stroke)
    context.setLineCap(.round)
    for (index, lens) in lenses.enumerated() {
        let outerX = index == 0 ? lens.minX : lens.maxX
        let direction: CGFloat = index == 0 ? -1 : 1
        context.move(to: CGPoint(x: outerX, y: lens.maxY - stroke / 2))
        context.addLine(to: CGPoint(x: outerX + direction * 92 * scale, y: lens.maxY + 28 * scale))
        context.strokePath()
    }

    // Bridge.
    context.setFillColor(frame)
    context.fill(CGRect(
        x: left + lensWidth - stroke / 2,
        y: top + lensHeight - stroke * 1.4,
        width: bridge + stroke,
        height: stroke
    ))

    for lens in lenses {
        let path = CGPath(roundedRect: lens, cornerWidth: corner, cornerHeight: corner, transform: nil)
        context.addPath(path)
        context.setFillColor(lime)
        context.fillPath()

        context.addPath(path)
        context.setStrokeColor(frame)
        context.setLineWidth(stroke)
        context.strokePath()

        drawRobotEye(in: context, lens: lens, scale: scale)
    }
}

/// The motif on the lenses: a rounded outline with two eyes, matching the
/// mascot's glasses.
func drawRobotEye(in context: CGContext, lens: CGRect, scale: CGFloat) {
    let inset = 52 * scale
    let body = lens.insetBy(dx: inset, dy: inset + 14 * scale)
    let path = CGPath(roundedRect: body, cornerWidth: 26 * scale, cornerHeight: 26 * scale, transform: nil)

    context.addPath(path)
    context.setStrokeColor(forest)
    context.setLineWidth(22 * scale)
    context.strokePath()

    let eye = 34 * scale
    let centreY = body.midY - eye / 2
    context.setFillColor(forest)
    for x in [body.minX + body.width * 0.28 - eye / 2, body.minX + body.width * 0.72 - eye / 2] {
        context.fill(CGRect(x: x, y: centreY, width: eye, height: eye))
    }
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

let iconset = outputDirectory.appending(path: "macdock.iconset")
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
    guard let image = drawMark(size: rung.pixels, includeGround: true) else { continue }
    try write(image, to: iconset.appending(path: "\(rung.name).png"))
}

// Kept separate so the foreground can be layered over a new ground when the
// mascot artwork arrives, per docs/BRANDING.md.
if let composite = drawMark(size: 1024, includeGround: true) {
    try write(composite, to: outputDirectory.appending(path: "icon-1024.png"))
}
if let foreground = drawMark(size: 1024, includeGround: false) {
    try write(foreground, to: outputDirectory.appending(path: "mark-foreground-1024.png"))
}

print("wrote \(rungs.count) rungs plus composite and foreground to \(outputDirectory.path)")
