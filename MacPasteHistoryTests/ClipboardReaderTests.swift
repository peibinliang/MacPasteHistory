import AppKit
import XCTest
@testable import MacPasteHistory

final class ClipboardReaderTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        pasteboard.clearContents()
        pasteboard.releaseGlobally()
        pasteboard = nil
        super.tearDown()
    }

    func testReadPlainText_whenPasteboardContainsText_shouldReturnText() {
        pasteboard.setString("Copied text", forType: .string)
        let reader = ClipboardReader(pasteboard: pasteboard)

        let text = reader.readPlainText()

        XCTAssertEqual(text, "Copied text")
    }

    func testReadPlainText_whenPasteboardContainsWhitespaceOnly_shouldReturnNil() {
        pasteboard.setString("   \n\t  ", forType: .string)
        let reader = ClipboardReader(pasteboard: pasteboard)

        let text = reader.readPlainText()

        XCTAssertNil(text)
    }

    func testReadPlainText_whenTextIsLongAndMultiline_shouldNotTruncateContent() {
        let original = String(repeating: "line with 中文 and emoji 😊\n", count: 500)
        pasteboard.setString(original, forType: .string)

        let result = ClipboardReader(pasteboard: pasteboard).readPlainText()

        XCTAssertEqual(result, original.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func testReadImage_whenPasteboardContainsPNG_shouldReturnPNGImageCandidate() throws {
        let pngData = try makePNGData(width: 12, height: 8)
        pasteboard.setData(pngData, forType: .png)
        let reader = ClipboardReader(pasteboard: pasteboard)

        let image = reader.readImage()

        XCTAssertEqual(image?.format, .png)
        XCTAssertEqual(image?.width, 12)
        XCTAssertEqual(image?.height, 8)
        XCTAssertEqual(image?.pngData, pngData)
    }

    func testReadImage_whenPasteboardContainsTIFF_shouldReturnPNGImageCandidate() throws {
        let tiffData = try makeTIFFData(width: 10, height: 6)
        pasteboard.setData(tiffData, forType: .tiff)
        let reader = ClipboardReader(pasteboard: pasteboard)

        let image = reader.readImage()

        XCTAssertEqual(image?.format, .png)
        XCTAssertEqual(image?.width, 10)
        XCTAssertEqual(image?.height, 6)
        XCTAssertNotNil(image?.pngData)
        XCTAssertNotEqual(image?.pngData, tiffData)
    }

    func testReadImage_whenPasteboardContainsOnlyText_shouldReturnNil() {
        pasteboard.setString("not an image", forType: .string)
        let reader = ClipboardReader(pasteboard: pasteboard)

        let image = reader.readImage()

        XCTAssertNil(image)
    }

    func testReadImage_whenPasteboardContainsFinderImageFileURL_shouldReturnPNGImageCandidate() throws {
        let imageURL = temporaryDirectory.appendingPathComponent("finder-image.png")
        try makePNGData(width: 16, height: 9).write(to: imageURL)
        pasteboard.writeObjects([imageURL as NSURL])
        let reader = ClipboardReader(pasteboard: pasteboard)

        let image = reader.readImage()

        XCTAssertEqual(image?.format, .png)
        XCTAssertEqual(image?.width, 16)
        XCTAssertEqual(image?.height, 9)
        XCTAssertNotNil(image?.pngData)
    }

    func testReadImage_whenPasteboardContainsFinderNonImageFileURL_shouldReturnNil() throws {
        let textURL = temporaryDirectory.appendingPathComponent("not-image.txt")
        try Data("plain file".utf8).write(to: textURL)
        pasteboard.writeObjects([textURL as NSURL])
        let reader = ClipboardReader(pasteboard: pasteboard)

        let image = reader.readImage()

        XCTAssertNil(image)
    }

    private func makePNGData(width: Int, height: Int) throws -> Data {
        guard let bitmap = makeBitmap(width: width, height: height),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw TestImageError.encodingFailed
        }
        return pngData
    }

    private func makeTIFFData(width: Int, height: Int) throws -> Data {
        guard let tiffData = makeBitmap(width: width, height: height)?.tiffRepresentation else {
            throw TestImageError.encodingFailed
        }
        return tiffData
    }

    private func makeBitmap(width: Int, height: Int) -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
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
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
}

private enum TestImageError: Error {
    case encodingFailed
}
