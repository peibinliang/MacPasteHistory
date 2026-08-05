#!/usr/bin/env swift
import AppKit
import Foundation

private let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/manual-qa-fixtures"
)

private struct TextFixture {
    let fileName: String
    let contents: String
}

private struct ImageFixture {
    let fileName: String
    let width: Int
    let height: Int
    let seed: UInt32
}

private enum FixtureError: Error, CustomStringConvertible {
    case couldNotCreateImage(String)
    case couldNotEncodePNG(String)

    var description: String {
        switch self {
        case .couldNotCreateImage(let fileName):
            return "Could not create image for \(fileName)"
        case .couldNotEncodePNG(let fileName):
            return "Could not encode PNG for \(fileName)"
        }
    }
}

private func largeText(repetitions: Int) -> String {
    let paragraph = [
        "粘易 manual QA large text sample.",
        "This line is synthetic and contains no private clipboard data.",
        "Search token: release-fixture-clipboard-history.",
        "Mixed language sample: copy test text, menu bar restore, history search.",
        "Numbers and punctuation: 0123456789 !@#$%^&*() [] {}."
    ].joined(separator: "\n")

    return (1...repetitions)
        .map { "Block \($0)\n\(paragraph)" }
        .joined(separator: "\n\n")
}

private let textFixtures: [TextFixture] = [
    TextFixture(
        fileName: "01-browser-text-sample.txt",
        contents: """
        粘易 browser copy sample

        Copy this text from Chrome or Safari and verify:
        - The text appears in history.
        - Search can find "browser copy sample".
        - Restore writes the same text back to the clipboard.
        - The source app is recorded when permission allows it.
        """
    ),
    TextFixture(
        fileName: "02-vscode-code-sample.swift",
        contents: """
        struct ClipboardFixture {
            let title: String
            let sourceApp: String

            func expectedPreview() -> String {
                "Synthetic QA sample copied from VS Code"
            }
        }
        """
    ),
    TextFixture(
        fileName: "03-chat-copy-sample.txt",
        contents: """
        QA chat sample, safe to paste into a non-private test conversation.

        Please copy this message from WeChat or DingTalk test chat and verify that
        non-blocked conversations are captured. Then add the app to the blocked
        app list and confirm new clipboard content is skipped.
        """
    ),
    TextFixture(
        fileName: "04-large-text-sample.txt",
        contents: largeText(repetitions: 18_000)
    )
]

private let imageFixtures: [ImageFixture] = [
    ImageFixture(fileName: "05-standard-image-1024x768.png", width: 1024, height: 768, seed: 17),
    ImageFixture(fileName: "06-large-image-2400x1600.png", width: 2400, height: 1600, seed: 91)
]

private func nextRandom(_ state: inout UInt32) -> UInt8 {
    state = state &* 1664525 &+ 1013904223
    return UInt8((state >> 16) & 0xFF)
}

private func pngData(width: Int, height: Int, seed: UInt32, fileName: String) throws -> Data {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
    var state = seed

    for y in 0..<height {
        for x in 0..<width {
            let index = y * bytesPerRow + x * bytesPerPixel
            let noise = nextRandom(&state)
            bytes[index] = UInt8((x * 255) / max(width - 1, 1)) ^ noise
            bytes[index + 1] = UInt8((y * 255) / max(height - 1, 1)) ^ (noise / 2)
            bytes[index + 2] = UInt8((x + y + Int(noise)) % 256)
            bytes[index + 3] = 255
        }
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    let data = Data(bytes)

    guard let provider = CGDataProvider(data: data as CFData),
          let image = CGImage(
              width: width,
              height: height,
              bitsPerComponent: 8,
              bitsPerPixel: 32,
              bytesPerRow: bytesPerRow,
              space: colorSpace,
              bitmapInfo: bitmapInfo,
              provider: provider,
              decode: nil,
              shouldInterpolate: false,
              intent: .defaultIntent
          ) else {
        throw FixtureError.couldNotCreateImage(fileName)
    }

    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw FixtureError.couldNotEncodePNG(fileName)
    }
    return png
}

private func manifest(generatedFiles: [URL]) -> String {
    let rows = generatedFiles
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .map { "- `\($0.lastPathComponent)`" }
        .joined(separator: "\n")

    return """
    # Manual QA Fixtures

    Generated: \(ISO8601DateFormatter().string(from: Date()))

    These files contain synthetic, non-private content for Release manual QA.

    ## Files

    \(rows)

    ## Suggested Use

    - Open `01-browser-text-sample.txt` in Chrome or Safari and copy text from the page/viewer.
    - Open `02-vscode-code-sample.swift` in VS Code and copy the code block.
    - Paste `03-chat-copy-sample.txt` into a non-private WeChat or DingTalk test chat, then copy it back.
    - Copy all of `04-large-text-sample.txt` for large text capture, search, and restore testing.
    - Open the PNG files in Preview, Safari, or Finder and copy them for image capture testing.

    Record actual results in `docs/release/manual-qa-record.md`.
    """
}

do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    var generatedFiles: [URL] = []

    for fixture in textFixtures {
        let fileURL = outputDirectory.appendingPathComponent(fixture.fileName)
        try fixture.contents.write(to: fileURL, atomically: true, encoding: .utf8)
        generatedFiles.append(fileURL)
    }

    for fixture in imageFixtures {
        let fileURL = outputDirectory.appendingPathComponent(fixture.fileName)
        let data = try pngData(width: fixture.width, height: fixture.height, seed: fixture.seed, fileName: fixture.fileName)
        try data.write(to: fileURL, options: .atomic)
        generatedFiles.append(fileURL)
    }

    let manifestURL = outputDirectory.appendingPathComponent("README.md")
    try manifest(generatedFiles: generatedFiles).write(to: manifestURL, atomically: true, encoding: .utf8)
    generatedFiles.append(manifestURL)

    print("Manual QA fixtures generated:")
    for fileURL in generatedFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        print("  \(fileURL.path)")
    }
} catch {
    fputs("Failed to generate manual QA fixtures: \(error)\n", stderr)
    exit(1)
}
