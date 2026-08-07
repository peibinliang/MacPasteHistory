import XCTest
@testable import MacPasteHistory

@MainActor
final class OCRViewModelTests: XCTestCase {
    func testRecognize_thenEditAndSave_persistsEditedTextAndRefreshes() async {
        let repository = FakeOCRRepository()
        var refreshCount = 0
        let viewModel = OCRViewModel(service: FakeOCRService(result: OCRResult(text: "recognized", observationsCount: 1, languages: ["en-US"])), repository: repository, didSave: { refreshCount += 1 })
        let item = imageItem()

        await viewModel.recognize(item: item)
        XCTAssertEqual(viewModel.state, .editing)
        XCTAssertEqual(viewModel.editableText, "recognized")
        viewModel.editableText = "edited recognition"
        await viewModel.save(item: item)

        XCTAssertEqual(repository.savedText, "edited recognition")
        XCTAssertEqual(repository.savedID, item.id)
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testCancel_doesNotPersistAndFailureAllowsRetry() async {
        let repository = FakeOCRRepository()
        let item = imageItem(ocrText: "previous")
        let viewModel = OCRViewModel(service: FailingOCRService(), repository: repository)

        viewModel.cancel()
        XCTAssertNil(repository.savedText)
        await viewModel.recognize(item: item)
        XCTAssertEqual(viewModel.state, .failed(.visionFailed))
        XCTAssertEqual(repository.failureCode, "visionFailed")
        XCTAssertNil(repository.savedText)
    }

    private func imageItem(ocrText: String? = nil) -> ClipboardHistoryItem {
        ClipboardHistoryItem(id: 7, contentType: .image, textContent: "", filePath: "/tmp/image.png", thumbnailPath: nil, sourceApp: nil, sourceBundleID: nil, contentHash: "image", textLength: 0, fileSize: 1, imageWidth: 1, imageHeight: 1, imageFormat: .png, isFavorite: false, isSensitive: false, createdAt: .distantPast, updatedAt: .distantPast, ocrText: ocrText)
    }
}

private final class FakeOCRRepository: OCRResultPersisting {
    var savedID: Int64?
    var savedText: String?
    var failureCode: String?
    func saveOCRResult(id: Int64, text: String, detection: ContentDetectionResult) throws { savedID = id; savedText = text }
    func markOCRFailure(id: Int64, errorCode: String, at date: Date) throws { failureCode = errorCode }
}

private struct FakeOCRService: OCRServicing {
    let result: OCRResult
    func recognizeText(in imageURL: URL) async throws -> OCRResult { result }
}

private struct FailingOCRService: OCRServicing {
    func recognizeText(in imageURL: URL) async throws -> OCRResult { throw OCRServiceError.visionFailed }
}
