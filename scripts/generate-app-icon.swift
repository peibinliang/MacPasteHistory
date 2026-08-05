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
private let sourceURL = repoRoot.appendingPathComponent("design/AppIconSource.png")
private let assetCatalogURL = repoRoot.appendingPathComponent("MacPasteHistory/Resources/Assets.xcassets", isDirectory: true)
private let iconsetURL = assetCatalogURL.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
private let statusIconsetURL = assetCatalogURL.appendingPathComponent("StatusBarIcon.imageset", isDirectory: true)

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
    case sourceImageMissing(String)
    case couldNotCreateBitmap(Int)
    case couldNotEncodePNG(Int)

    var description: String {
        switch self {
        case .sourceImageMissing(let path):
            return "Source image is missing or unreadable: \(path)"
        case .couldNotCreateBitmap(let pixels):
            return "Could not create bitmap for \(pixels)x\(pixels) icon"
        case .couldNotEncodePNG(let pixels):
            return "Could not encode PNG for \(pixels)x\(pixels) icon"
        }
    }
}

private func pngData(width: Int, height: Int, draw: (NSRect) -> Void) throws -> Data {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconGenerationError.couldNotCreateBitmap(max(width, height))
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    let rect = NSRect(x: 0, y: 0, width: width, height: height)
    NSColor.clear.setFill()
    rect.fill()
    draw(rect)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.couldNotEncodePNG(max(width, height))
    }
    return data
}

private func appIconData(source: NSImage, pixels: Int) throws -> Data {
    try pngData(width: pixels, height: pixels) { rect in
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

private func statusIconData(pixels: Int) throws -> Data {
    try pngData(width: pixels, height: pixels) { rect in
        let scale = CGFloat(pixels) / 18
        NSColor.black.setStroke()

        let clipboard = NSBezierPath(roundedRect: NSRect(x: 3 * scale, y: 2 * scale, width: 10 * scale, height: 13 * scale), xRadius: 2 * scale, yRadius: 2 * scale)
        clipboard.lineWidth = 1.45 * scale
        clipboard.stroke()

        let clip = NSBezierPath(roundedRect: NSRect(x: 5.3 * scale, y: 13.2 * scale, width: 5.4 * scale, height: 2.5 * scale), xRadius: 1.1 * scale, yRadius: 1.1 * scale)
        clip.lineWidth = 1.45 * scale
        clip.stroke()

        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 7 * scale, y: 8.5 * scale))
        arrow.line(to: NSPoint(x: 16 * scale, y: 8.5 * scale))
        arrow.move(to: NSPoint(x: 12.8 * scale, y: 11.5 * scale))
        arrow.line(to: NSPoint(x: 16 * scale, y: 8.5 * scale))
        arrow.line(to: NSPoint(x: 12.8 * scale, y: 5.5 * scale))
        arrow.lineWidth = 1.7 * scale
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.stroke()

        let cursor = NSBezierPath()
        cursor.move(to: NSPoint(x: 16 * scale, y: 4.4 * scale))
        cursor.line(to: NSPoint(x: 16 * scale, y: 12.6 * scale))
        cursor.lineWidth = 1.2 * scale
        cursor.lineCapStyle = .round
        cursor.stroke()
    }
}

private func appIconContentsJSON() -> String {
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

private let statusIconContentsJSON = """
{
  "images" : [
    {
      "filename" : "status-bar-icon.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "status-bar-icon@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
"""

do {
    guard let source = NSImage(contentsOf: sourceURL) else {
        throw IconGenerationError.sourceImageMissing(sourceURL.path)
    }
    try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: statusIconsetURL, withIntermediateDirectories: true)

    for slot in slots {
        let data = try appIconData(source: source, pixels: slot.pixels)
        try data.write(to: iconsetURL.appendingPathComponent(slot.filename), options: .atomic)
    }
    try appIconContentsJSON().write(to: iconsetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

    try statusIconData(pixels: 18).write(to: statusIconsetURL.appendingPathComponent("status-bar-icon.png"), options: .atomic)
    try statusIconData(pixels: 36).write(to: statusIconsetURL.appendingPathComponent("status-bar-icon@2x.png"), options: .atomic)
    try statusIconContentsJSON.write(to: statusIconsetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

    print("Generated \(slots.count) AppIcon assets and 2 StatusBarIcon assets from \(sourceURL.path)")
} catch {
    fputs("Failed to generate icon assets: \(error)\n", stderr)
    exit(1)
}
