// Renders the README banner: the icon, the wordmark and the tagline, and the
// quokka when its render is in docs/media.
//
//   swift tools/make-banner.swift docs/media

import AppKit

let media = URL(filePath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/media")
let size = NSSize(width: 1520, height: 440)
let canvas = NSImage(size: size)
canvas.lockFocus()

NSColor(red: 0.059, green: 0.071, blue: 0.063, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

let iconPath = media.deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "assets/branding/DockNanny.iconset/icon_256x256@2x.png").path
if let icon = NSImage(contentsOfFile: iconPath) {
    icon.draw(in: NSRect(x: 90, y: 70, width: 300, height: 300))
}

func draw(_ text: String, x: CGFloat, baseline: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor, tracking: CGFloat = 0) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: tracking
    ]
    NSAttributedString(string: text, attributes: attributes).draw(at: NSPoint(x: x, y: baseline))
}

let ink = NSColor(red: 0.929, green: 0.937, blue: 0.918, alpha: 1)
let lime = NSColor(red: 0.545, green: 0.773, blue: 0.247, alpha: 1)
let muted = NSColor(red: 0.604, green: 0.627, blue: 0.604, alpha: 1)
draw("DockNanny", x: 450, baseline: 218, size: 128, weight: .bold, color: ink, tracking: -3)
draw("A dock on every display.", x: 456, baseline: 150, size: 46, weight: .medium, color: lime)
draw("The one macOS won't give you.", x: 456, baseline: 92, size: 30, weight: .regular, color: muted)

// The mascot, once its render exists: waving in from the right edge.
if let quokka = NSImage(contentsOfFile: media.appending(path: "quokka-wave.png").path) {
    let height: CGFloat = 400
    let width = height * quokka.size.width / quokka.size.height
    quokka.draw(in: NSRect(x: size.width - width - 40, y: 20, width: width, height: height))
}

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode the banner")
}
try png.write(to: media.appending(path: "banner.png"))
print("wrote banner.png (\(Int(size.width)) by \(Int(size.height)))")
