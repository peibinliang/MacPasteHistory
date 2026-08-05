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

    private func observation(_ text: String, x: CGFloat, y: CGFloat) -> OCRTextObservation {
        OCRTextObservation(text: text, boundingBox: CGRect(x: x, y: y, width: 0.1, height: 0.1), language: text == "bottom" ? "en-US" : "zh-Hans")
    }
}

private struct FakeOCRExecutor: OCRRequestExecuting {
    let observations: [OCRTextObservation]
    func recognizeObservations(in imageURL: URL) async throws -> [OCRTextObservation] { observations }
}
