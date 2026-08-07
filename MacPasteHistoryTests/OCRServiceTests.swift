import AppKit
import XCTest
@testable import MacPasteHistory

final class OCRServiceTests: XCTestCase {
    func testRecognize_ordersObservationsTopToBottomThenLeftToRight() async throws {
        let executor = FakeOCRExecutor(observations: [
            observation("bottom", x: 0.2, y: 0.1),
            observation("top right", x: 0.8, y: 0.8),
            observation("top left", x: 0.1, y: 0.8)
        ])

        let result = try await OCRService(executor: executor).recognizeText(in: URL(fileURLWithPath: "/unused.png"))

        XCTAssertEqual(result.text, "top left\ntop right\nbottom")
        XCTAssertEqual(result.observationsCount, 3)
        XCTAssertEqual(result.languages, ["en-US", "zh-Hans"])
    }

    func testRecognize_throwsNoTextFoundForEmptyObservations() async {
        do {
            _ = try await OCRService(executor: FakeOCRExecutor(observations: [])).recognizeText(in: URL(fileURLWithPath: "/unused.png"))
            XCTFail("Expected noTextFound")
        } catch let error as OCRServiceError {
            XCTAssertEqual(error, .noTextFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDefaultExecutorReportsMissingAndUndecodableImageFiles() async throws {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        await assertOCRFailure(.imageMissing) {
            try await OCRService().recognizeText(in: missingURL)
        }

        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try Data("not an image".utf8).write(to: invalidURL)
        defer { try? FileManager.default.removeItem(at: invalidURL) }
        await assertOCRFailure(.imageDecodeFailed) {
            try await OCRService().recognizeText(in: invalidURL)
        }
    }

    func testDefaultExecutorRecognizesGeneratedLocalImage() async throws {
        let imageURL = try makeTextImage("HELLO 123")
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let result = try await OCRService().recognizeText(in: imageURL)

        XCTAssertTrue(result.text.uppercased().contains("HELLO"))
        XCTAssertGreaterThan(result.observationsCount, 0)
    }

    private func assertOCRFailure(
        _ expected: OCRServiceError,
        operation: () async throws -> OCRResult
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected \(expected)")
        } catch let error as OCRServiceError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func observation(_ text: String, x: CGFloat, y: CGFloat) -> OCRTextObservation {
        OCRTextObservation(text: text, boundingBox: CGRect(x: x, y: y, width: 0.1, height: 0.1), language: text == "bottom" ? "en-US" : "zh-Hans")
    }

    private func makeTextImage(_ text: String) throws -> URL {
        let size = NSSize(width: 1_000, height: 260)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        text.draw(
            at: NSPoint(x: 70, y: 75),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 96, weight: .bold),
                .foregroundColor: NSColor.black
            ]
        )
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw OCRServiceError.imageDecodeFailed
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try pngData.write(to: url)
        return url
    }
}

private struct FakeOCRExecutor: OCRRequestExecuting {
    let observations: [OCRTextObservation]
    func recognizeObservations(in imageURL: URL) async throws -> [OCRTextObservation] { observations }
}
