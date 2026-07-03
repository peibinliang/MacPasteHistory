#!/usr/bin/env swift
import AppKit
import Foundation

private struct IconSlot {
    let size: String
    let scale: String
    let pixels: Int

    var filename: String {
        let normalizedSize = size.replacingOccurrences(of: "x", with: "-")
        return "app-icon-\(normalizedSize)-\(scale)-\(pixels).png"
    }
}

private let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let iconsetURL = repoRoot
    .appendingPathComponent("MacPasteHistory/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

private let slots: [IconSlot] = [
    IconSlot(size: "16x16", scale: "1x", pixels: 16),
    IconSlot(size: "16x16", scale: "2x", pixels: 32),
    IconSlot(size: "32x32", scale: "1x", pixels: 32),
    IconSlot(size: "32x32", scale: "2x", pixels: 64),
    IconSlot(size: "128x128", scale: "1x", pixels: 128),
    IconSlot(size: "128x128", scale: "2x", pixels: 256),
    IconSlot(size: "256x256", scale: "1x", pixels: 256),
    IconSlot(size: "256x256", scale: "2x", pixels: 512),
    IconSlot(size: "512x512", scale: "1x", pixels: 512),
    IconSlot(size: "512x512", scale: "2x", pixels: 1024)
]

private enum IconGenerationError: Error, CustomStringConvertible {
    case couldNotCreateBitmap(Int)
    case couldNotEncodePNG(Int)

    var description: String {
        switch self {
        case .couldNotCreateBitmap(let pixels):
            return "Could not create bitmap for \(pixels)x\(pixels) icon"
        case .couldNotEncodePNG(let pixels):
            return "Could not encode PNG for \(pixels)x\(pixels) icon"
        }
    }
}

private func scaled(_ value: CGFloat, _ pixels: Int) -> CGFloat {
    value * CGFloat(pixels) / 1024.0
}

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

private func drawIcon(size pixels: Int) throws -> Data {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconGenerationError.couldNotCreateBitmap(pixels)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    rect.fill()

    let corner = scaled(220, pixels)
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: scaled(72, pixels), dy: scaled(72, pixels)), xRadius: corner, yRadius: corner)
    let gradient = NSGradient(colors: [
        color(30, 110, 166),
        color(26, 163, 151)
    ])
    gradient?.draw(in: background, angle: 45)

    let boardRect = NSRect(
        x: scaled(246, pixels),
        y: scaled(204, pixels),
        width: scaled(532, pixels),
        height: scaled(644, pixels)
    )
    let board = NSBezierPath(roundedRect: boardRect, xRadius: scaled(76, pixels), yRadius: scaled(76, pixels))
    color(248, 252, 255).setFill()
    board.fill()
    color(12, 73, 114, 0.20).setStroke()
    board.lineWidth = max(1, scaled(12, pixels))
    board.stroke()

    let clipRect = NSRect(
        x: scaled(374, pixels),
        y: scaled(744, pixels),
        width: scaled(276, pixels),
        height: scaled(96, pixels)
    )
    let clip = NSBezierPath(roundedRect: clipRect, xRadius: scaled(42, pixels), yRadius: scaled(42, pixels))
    color(16, 95, 142).setFill()
    clip.fill()

    let clipInner = NSBezierPath(roundedRect: clipRect.insetBy(dx: scaled(76, pixels), dy: scaled(28, pixels)), xRadius: scaled(18, pixels), yRadius: scaled(18, pixels))
    color(190, 232, 231).setFill()
    clipInner.fill()

    let lineColor = color(32, 105, 145, 0.82)
    lineColor.setStroke()
    let lineWidth = max(1.5, scaled(26, pixels))
    let lineStartX = scaled(338, pixels)
    let lineEndX = scaled(686, pixels)
    for y in [scaled(624, pixels), scaled(524, pixels), scaled(424, pixels)] {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: lineStartX, y: y))
        line.line(to: NSPoint(x: lineEndX, y: y))
        line.lineWidth = lineWidth
        line.lineCapStyle = .round
        line.stroke()
    }

    let check = NSBezierPath()
    check.move(to: NSPoint(x: scaled(366, pixels), y: scaled(324, pixels)))
    check.line(to: NSPoint(x: scaled(464, pixels), y: scaled(260, pixels)))
    check.line(to: NSPoint(x: scaled(650, pixels), y: scaled(356, pixels)))
    check.lineWidth = max(2, scaled(34, pixels))
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    color(15, 151, 136).setStroke()
    check.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.couldNotEncodePNG(pixels)
    }
    return data
}

private func contentsJSON() -> String {
    let rows = slots.map { slot in
        """
            {
              "filename" : "\(slot.filename)",
              "idiom" : "mac",
              "scale" : "\(slot.scale)",
              "size" : "\(slot.size)"
            }
        """
    }.joined(separator: ",\n")

    return """
    {
      "images" : [
    \(rows)
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
}

do {
    try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    let existingIcons = try FileManager.default.contentsOfDirectory(at: iconsetURL, includingPropertiesForKeys: nil)
    for iconURL in existingIcons where iconURL.lastPathComponent.hasPrefix("app-icon-") && iconURL.pathExtension == "png" {
        try FileManager.default.removeItem(at: iconURL)
    }

    for slot in slots {
        let data = try drawIcon(size: slot.pixels)
        try data.write(to: iconsetURL.appendingPathComponent(slot.filename), options: .atomic)
    }

    try contentsJSON().write(
        to: iconsetURL.appendingPathComponent("Contents.json"),
        atomically: true,
        encoding: .utf8
    )

    print("Generated AppIcon assets:")
    for slot in slots {
        print("  \(iconsetURL.appendingPathComponent(slot.filename).path)")
    }
} catch {
    fputs("Failed to generate AppIcon assets: \(error)\n", stderr)
    exit(1)
}
