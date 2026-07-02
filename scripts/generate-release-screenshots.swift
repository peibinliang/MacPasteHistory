#!/usr/bin/env swift
import AppKit
import Foundation

private let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/release/screenshots")
private let canvasSize = NSSize(width: 2880, height: 1800)

private enum Colors {
    static let background = NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.98, alpha: 1.0)
    static let ink = NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.17, alpha: 1.0)
    static let muted = NSColor(calibratedRed: 0.37, green: 0.43, blue: 0.50, alpha: 1.0)
    static let panel = NSColor.white
    static let line = NSColor(calibratedRed: 0.84, green: 0.87, blue: 0.90, alpha: 1.0)
    static let blue = NSColor(calibratedRed: 0.05, green: 0.32, blue: 0.76, alpha: 1.0)
    static let green = NSColor(calibratedRed: 0.10, green: 0.55, blue: 0.34, alpha: 1.0)
    static let amber = NSColor(calibratedRed: 0.86, green: 0.49, blue: 0.11, alpha: 1.0)
    static let red = NSColor(calibratedRed: 0.76, green: 0.16, blue: 0.18, alpha: 1.0)
}

private struct Screenshot {
    let fileName: String
    let title: String
    let subtitle: String
    let draw: (CGRect) -> Void
}

private func attributes(size: CGFloat, weight: NSFont.Weight, color: NSColor) -> [NSAttributedString.Key: Any] {
    [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: 0
    ]
}

private func drawText(_ text: String, in rect: CGRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = Colors.ink) {
    (text as NSString).draw(in: rect, withAttributes: attributes(size: size, weight: weight, color: color))
}

private func fill(_ rect: CGRect, color: NSColor, radius: CGFloat = 0) {
    color.setFill()
    if radius > 0 {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    } else {
        rect.fill()
    }
}

private func stroke(_ rect: CGRect, color: NSColor = Colors.line, radius: CGFloat = 0, width: CGFloat = 2) {
    color.setStroke()
    let path = radius > 0 ? NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius) : NSBezierPath(rect: rect)
    path.lineWidth = width
    path.stroke()
}

private func drawSymbol(_ name: String, in rect: CGRect, color: NSColor = Colors.blue) {
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
    image.isTemplate = true
    color.set()
    image.draw(in: rect)
}

private func drawWindowShell(in rect: CGRect, title: String) -> CGRect {
    fill(rect, color: Colors.panel, radius: 28)
    stroke(rect, radius: 28, width: 2)
    let titleBar = CGRect(x: rect.minX, y: rect.maxY - 92, width: rect.width, height: 92)
    fill(titleBar, color: NSColor(calibratedWhite: 0.98, alpha: 1.0), radius: 28)
    drawText(title, in: CGRect(x: rect.minX + 120, y: titleBar.minY + 26, width: rect.width - 240, height: 44), size: 30, weight: .semibold)
    for index in 0..<3 {
        let colors = [Colors.red, Colors.amber, Colors.green]
        fill(CGRect(x: rect.minX + 34 + CGFloat(index) * 34, y: titleBar.minY + 34, width: 18, height: 18), color: colors[index], radius: 9)
    }
    return rect.insetBy(dx: 52, dy: 132)
}

private func drawToolbar(in rect: CGRect) {
    fill(CGRect(x: rect.minX, y: rect.maxY - 74, width: rect.width, height: 74), color: NSColor(calibratedWhite: 0.96, alpha: 1), radius: 14)
    drawSymbol("doc.on.clipboard", in: CGRect(x: rect.minX + 24, y: rect.maxY - 55, width: 30, height: 30))
    drawText("Clipboard History", in: CGRect(x: rect.minX + 68, y: rect.maxY - 58, width: 360, height: 38), size: 28, weight: .semibold)
    fill(CGRect(x: rect.maxX - 185, y: rect.maxY - 60, width: 150, height: 42), color: Colors.red.withAlphaComponent(0.08), radius: 8)
    drawText("Clear Text", in: CGRect(x: rect.maxX - 150, y: rect.maxY - 51, width: 110, height: 26), size: 18, weight: .medium, color: Colors.red)
}

private func drawSearch(in rect: CGRect) {
    fill(rect, color: NSColor(calibratedWhite: 0.96, alpha: 1), radius: 12)
    stroke(rect, radius: 12, width: 1)
    drawSymbol("magnifyingglass", in: CGRect(x: rect.minX + 20, y: rect.minY + 18, width: 28, height: 28), color: Colors.muted)
    drawText("Search text history", in: CGRect(x: rect.minX + 64, y: rect.minY + 15, width: rect.width - 88, height: 34), size: 22, color: Colors.muted)
}

private func drawFilterTabs(in rect: CGRect, selected: String) {
    fill(rect, color: NSColor(calibratedWhite: 0.95, alpha: 1), radius: 12)
    let tabs = ["All", "Text", "Image"]
    let tabWidth = rect.width / CGFloat(tabs.count)
    for (index, tab) in tabs.enumerated() {
        let tabRect = CGRect(x: rect.minX + CGFloat(index) * tabWidth + 5, y: rect.minY + 5, width: tabWidth - 10, height: rect.height - 10)
        if tab == selected {
            fill(tabRect, color: Colors.panel, radius: 9)
            stroke(tabRect, color: Colors.line, radius: 9, width: 1)
        }
        drawText(tab, in: CGRect(x: tabRect.minX, y: tabRect.minY + 13, width: tabRect.width, height: 26), size: 19, weight: .medium, color: tab == selected ? Colors.ink : Colors.muted)
    }
}

private func drawHistoryRow(in rect: CGRect, icon: String, title: String, meta: String, accent: NSColor, favorite: Bool = false) {
    fill(rect, color: NSColor(calibratedWhite: 0.99, alpha: 1.0), radius: 14)
    stroke(rect, radius: 14, width: 1)
    fill(CGRect(x: rect.minX + 22, y: rect.midY - 25, width: 50, height: 50), color: accent.withAlphaComponent(0.10), radius: 10)
    drawSymbol(icon, in: CGRect(x: rect.minX + 34, y: rect.midY - 13, width: 26, height: 26), color: accent)
    drawText(meta, in: CGRect(x: rect.minX + 92, y: rect.maxY - 39, width: rect.width - 220, height: 24), size: 16, color: Colors.muted)
    drawText(title, in: CGRect(x: rect.minX + 92, y: rect.minY + 25, width: rect.width - 220, height: 38), size: 22, weight: .medium)
    drawSymbol(favorite ? "star.fill" : "star", in: CGRect(x: rect.maxX - 120, y: rect.midY - 12, width: 24, height: 24), color: favorite ? Colors.amber : Colors.muted)
    drawSymbol("arrow.uturn.backward", in: CGRect(x: rect.maxX - 74, y: rect.midY - 12, width: 24, height: 24), color: Colors.blue)
    drawSymbol("trash", in: CGRect(x: rect.maxX - 30, y: rect.midY - 12, width: 24, height: 24), color: Colors.red)
}

private func drawSettingsRow(in rect: CGRect, title: String, value: String, isOn: Bool? = nil) {
    drawText(title, in: CGRect(x: rect.minX, y: rect.minY + 13, width: rect.width * 0.58, height: 32), size: 22)
    if let isOn {
        let toggle = CGRect(x: rect.maxX - 84, y: rect.minY + 12, width: 70, height: 34)
        fill(toggle, color: isOn ? Colors.green : Colors.line, radius: 17)
        let knobX = isOn ? toggle.maxX - 30 : toggle.minX + 4
        fill(CGRect(x: knobX, y: toggle.minY + 4, width: 26, height: 26), color: Colors.panel, radius: 13)
    } else {
        drawText(value, in: CGRect(x: rect.maxX - 260, y: rect.minY + 13, width: 246, height: 32), size: 22, weight: .medium, color: Colors.blue)
    }
    stroke(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1), color: Colors.line, width: 1)
}

private func drawScreenshot(_ screenshot: Screenshot) throws {
    let image = NSImage(size: canvasSize)
    image.lockFocus()
    fill(CGRect(origin: .zero, size: canvasSize), color: Colors.background)
    drawText(screenshot.title, in: CGRect(x: 150, y: 1570, width: 1320, height: 86), size: 64, weight: .bold)
    drawText(screenshot.subtitle, in: CGRect(x: 154, y: 1494, width: 1320, height: 54), size: 28, color: Colors.muted)
    screenshot.draw(CGRect(x: 150, y: 120, width: 2580, height: 1320))
    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ScreenshotRender", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render PNG"])
    }

    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try pngData.write(to: outputDirectory.appendingPathComponent(screenshot.fileName), options: .atomic)
}

private let screenshots: [Screenshot] = [
    Screenshot(
        fileName: "01-history-overview.png",
        title: "Clipboard History at a Glance",
        subtitle: "Search, filter, favorite, restore, and delete local clipboard records from the menu bar.",
        draw: { frame in
            let content = drawWindowShell(in: frame, title: "MacPasteHistory")
            drawToolbar(in: content)
            drawSearch(in: CGRect(x: content.minX, y: content.maxY - 160, width: content.width, height: 64))
            drawFilterTabs(in: CGRect(x: content.minX + 180, y: content.maxY - 236, width: 420, height: 58), selected: "All")
            let rowTop = content.maxY - 350
            drawHistoryRow(in: CGRect(x: content.minX, y: rowTop, width: content.width, height: 116), icon: "doc.text", title: "Release notes draft copied from VS Code", meta: "Text  2 min ago  43 chars  VS Code", accent: Colors.blue, favorite: true)
            drawHistoryRow(in: CGRect(x: content.minX, y: rowTop - 140, width: content.width, height: 116), icon: "photo", title: "Image 1024x768", meta: "Image  8 min ago  1.4 MB  Safari", accent: Colors.green)
            drawHistoryRow(in: CGRect(x: content.minX, y: rowTop - 280, width: content.width, height: 116), icon: "doc.text", title: "Searchable support reply snippet", meta: "Text  Today  128 chars  Chrome", accent: Colors.blue)
            fill(CGRect(x: content.minX + 120, y: content.minY + 70, width: content.width - 240, height: 76), color: Colors.blue.withAlphaComponent(0.08), radius: 14)
            drawText("Restored to clipboard", in: CGRect(x: content.minX + 165, y: content.minY + 91, width: 360, height: 34), size: 24, weight: .medium, color: Colors.blue)
        }
    ),
    Screenshot(
        fileName: "02-image-history.png",
        title: "Text and Image Clipboard Capture",
        subtitle: "Keep image metadata, thumbnails, dimensions, and source app context together.",
        draw: { frame in
            let content = drawWindowShell(in: frame, title: "Image History")
            drawToolbar(in: content)
            drawFilterTabs(in: CGRect(x: content.minX, y: content.maxY - 150, width: 420, height: 58), selected: "Image")
            let preview = CGRect(x: content.minX + 60, y: content.minY + 115, width: 980, height: 760)
            fill(preview, color: NSColor(calibratedRed: 0.86, green: 0.93, blue: 0.90, alpha: 1), radius: 22)
            for index in 0..<9 {
                let x = preview.minX + 60 + CGFloat(index % 3) * 285
                let y = preview.minY + 80 + CGFloat(index / 3) * 205
                fill(CGRect(x: x, y: y, width: 220, height: 140), color: [Colors.green, Colors.blue, Colors.amber][index % 3].withAlphaComponent(0.28), radius: 18)
            }
            let detail = CGRect(x: content.minX + 1130, y: content.minY + 115, width: content.width - 1190, height: 760)
            fill(detail, color: NSColor(calibratedWhite: 0.985, alpha: 1), radius: 22)
            stroke(detail, radius: 22, width: 1)
            drawText("Image Detail", in: CGRect(x: detail.minX + 48, y: detail.maxY - 90, width: 500, height: 44), size: 34, weight: .semibold)
            drawText("Type        Image", in: CGRect(x: detail.minX + 48, y: detail.maxY - 170, width: 520, height: 36), size: 24)
            drawText("Dimensions  1024x768", in: CGRect(x: detail.minX + 48, y: detail.maxY - 225, width: 520, height: 36), size: 24)
            drawText("Format      PNG", in: CGRect(x: detail.minX + 48, y: detail.maxY - 280, width: 520, height: 36), size: 24)
            drawText("Source      Safari", in: CGRect(x: detail.minX + 48, y: detail.maxY - 335, width: 520, height: 36), size: 24)
            fill(CGRect(x: detail.minX + 48, y: detail.minY + 78, width: 250, height: 66), color: Colors.blue, radius: 12)
            drawText("Restore", in: CGRect(x: detail.minX + 118, y: detail.minY + 96, width: 130, height: 34), size: 24, weight: .semibold, color: Colors.panel)
        }
    ),
    Screenshot(
        fileName: "03-settings-controls.png",
        title: "Flexible Recording Controls",
        subtitle: "Tune recording, launch behavior, retention, and storage limits from one settings window.",
        draw: { frame in
            let content = drawWindowShell(in: frame, title: "Settings")
            let card = CGRect(x: content.minX + 260, y: content.minY + 110, width: content.width - 520, height: content.height - 120)
            fill(card, color: NSColor(calibratedWhite: 0.985, alpha: 1), radius: 22)
            stroke(card, radius: 22, width: 1)
            drawText("Recording", in: CGRect(x: card.minX + 54, y: card.maxY - 82, width: 460, height: 42), size: 32, weight: .semibold)
            drawSettingsRow(in: CGRect(x: card.minX + 54, y: card.maxY - 160, width: card.width - 108, height: 60), title: "Record text clipboard history", value: "", isOn: true)
            drawSettingsRow(in: CGRect(x: card.minX + 54, y: card.maxY - 230, width: card.width - 108, height: 60), title: "Record image clipboard history", value: "", isOn: true)
            drawSettingsRow(in: CGRect(x: card.minX + 54, y: card.maxY - 300, width: card.width - 108, height: 60), title: "Launch at login", value: "", isOn: true)
            drawText("History Retention", in: CGRect(x: card.minX + 54, y: card.maxY - 400, width: 460, height: 42), size: 32, weight: .semibold)
            drawSettingsRow(in: CGRect(x: card.minX + 54, y: card.maxY - 480, width: card.width - 108, height: 60), title: "Keep history for", value: "30 days")
            drawSettingsRow(in: CGRect(x: card.minX + 54, y: card.maxY - 550, width: card.width - 108, height: 60), title: "Maximum text records", value: "1000")
            drawSettingsRow(in: CGRect(x: card.minX + 54, y: card.maxY - 620, width: card.width - 108, height: 60), title: "Single image size limit", value: "20 MB")
            drawSettingsRow(in: CGRect(x: card.minX + 54, y: card.maxY - 690, width: card.width - 108, height: 60), title: "Total storage cap", value: "500 MB")
        }
    ),
    Screenshot(
        fileName: "04-local-privacy.png",
        title: "Private by Design",
        subtitle: "Clipboard history stays local, with pause, blocked apps, cleanup, and clear-all controls.",
        draw: { frame in
            let content = drawWindowShell(in: frame, title: "Privacy and Data")
            let items = [
                ("lock.shield", "Local-only storage", "Text, image files, and thumbnails stay in the app container.", Colors.green),
                ("pause.circle", "Pause recording anytime", "Stop capture before handling sensitive workflows.", Colors.blue),
                ("eye.slash", "Sensitive content filtering", "Password, token, key, and verification-code patterns are skipped.", Colors.amber),
                ("trash", "Clear all data", "Delete database records, originals, and thumbnails together.", Colors.red)
            ]
            for (index, item) in items.enumerated() {
                let row = CGRect(x: content.minX + 160, y: content.maxY - 225 - CGFloat(index) * 205, width: content.width - 320, height: 150)
                fill(row, color: NSColor(calibratedWhite: 0.985, alpha: 1), radius: 20)
                stroke(row, radius: 20, width: 1)
                fill(CGRect(x: row.minX + 38, y: row.midY - 38, width: 76, height: 76), color: item.3.withAlphaComponent(0.12), radius: 18)
                drawSymbol(item.0, in: CGRect(x: row.minX + 57, y: row.midY - 19, width: 38, height: 38), color: item.3)
                drawText(item.1, in: CGRect(x: row.minX + 150, y: row.maxY - 61, width: row.width - 190, height: 38), size: 30, weight: .semibold)
                drawText(item.2, in: CGRect(x: row.minX + 150, y: row.minY + 32, width: row.width - 190, height: 34), size: 23, color: Colors.muted)
            }
        }
    )
]

for screenshot in screenshots {
    try drawScreenshot(screenshot)
    print("Generated \(outputDirectory.path)/\(screenshot.fileName)")
}
