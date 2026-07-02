import AppKit
import XCTest
@testable import MacPasteHistory

final class ClipboardWriterTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
    }

    override func tearDown() {
        pasteboard.clearContents()
        pasteboard.releaseGlobally()
        pasteboard = nil
        super.tearDown()
    }

    func testWriteText_shouldWritePlainTextAndMarkNextChangeToSkip() {
        let restorationState = ClipboardRestorationState()
        let writer = ClipboardWriter(pasteboard: pasteboard, restorationState: restorationState)

        XCTAssertTrue(writer.writeText("restored text"))

        XCTAssertEqual(pasteboard.string(forType: .string), "restored text")
        XCTAssertTrue(restorationState.consumeShouldSkipNextChange())
        XCTAssertFalse(restorationState.consumeShouldSkipNextChange())
    }

    func testWriteImage_shouldWritePNGDataAndMarkNextChangeToSkip() throws {
        let restorationState = ClipboardRestorationState()
        let writer = ClipboardWriter(pasteboard: pasteboard, restorationState: restorationState)
        let pngData = try makePNGData()

        XCTAssertTrue(writer.writeImage(pngData))

        XCTAssertEqual(pasteboard.data(forType: .png), pngData)
        XCTAssertTrue(restorationState.consumeShouldSkipNextChange())
    }

    private func makePNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw TestImageError.encodingFailed
        }
        return pngData
    }
}

private enum TestImageError: Error {
    case encodingFailed
}
