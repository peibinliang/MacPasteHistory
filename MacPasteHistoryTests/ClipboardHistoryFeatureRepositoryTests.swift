import XCTest

@testable import MacPasteHistory

final class ClipboardHistoryFeatureRepositoryTests: XCTestCase {
    private var temporaryDatabase: TemporaryDatabase!
    private var repository: ClipboardHistoryRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDatabase = try TemporaryDatabase()
        try MigrationManager(database: temporaryDatabase.connection).migrate()
        repository = ClipboardHistoryRepository(database: temporaryDatabase.connection)
    }

    override func tearDownWithError() throws {
        repository = nil
        temporaryDatabase?.remove()
        temporaryDatabase = nil
        try super.tearDownWithError()
    }

    func testRecordUsage_updatesCopyAndPasteIndependentlyWithoutChangingCaptureMetadata() throws {
        let item = try repository.saveText(
            "usage record",
            sourceApp: "Notes",
            sourceBundleID: "com.apple.Notes"
        )
        let copyDate = Date(timeIntervalSince1970: 1_700_000_000)
        let pasteDate = Date(timeIntervalSince1970: 1_700_000_060)

        try repository.recordReuseCopy(historyID: item.id, at: copyDate)
        try repository.recordPaste(historyID: item.id, at: pasteDate)

        let updatedItem = try historyItem(id: item.id)
        XCTAssertEqual(updatedItem.reuseCopyCount, 1)
        XCTAssertEqual(updatedItem.lastReuseCopiedAt, copyDate)
        XCTAssertEqual(updatedItem.pasteCount, 1)
        XCTAssertEqual(updatedItem.lastPastedAt, pasteDate)
        XCTAssertEqual(updatedItem.captureCount, item.captureCount)
        XCTAssertEqual(updatedItem.sourceApp, item.sourceApp)
        XCTAssertEqual(updatedItem.sourceBundleID, item.sourceBundleID)
        XCTAssertEqual(updatedItem.createdAt, item.createdAt)
        XCTAssertEqual(updatedItem.lastCapturedAt, item.lastCapturedAt)
    }

    func testTypeAndOCRUpdates_persistMetadataAndKeepImagesAsImages() throws {
        let textItem = try repository.saveText("detected text", sourceApp: nil, sourceBundleID: nil)
        let detectionDate = Date(timeIntervalSince1970: 1_700_000_000)
        let detected = ContentDetectionResult(type: .json, confidence: 0.85, version: 3, detectedAt: detectionDate)

        try repository.updateDetectedType(id: textItem.id, result: detected)
        try repository.updateUserOverrideType(id: textItem.id, type: .url)
        XCTAssertEqual(try historyItem(id: textItem.id).userOverrideType, .url)
        try repository.updateUserOverrideType(id: textItem.id, type: nil)

        let updatedTextItem = try historyItem(id: textItem.id)
        XCTAssertEqual(updatedTextItem.detectedType, .json)
        XCTAssertEqual(updatedTextItem.detectionConfidence, 0.85)
        XCTAssertEqual(updatedTextItem.detectionVersion, 3)
        XCTAssertEqual(updatedTextItem.detectedAt, detectionDate)
        XCTAssertNil(updatedTextItem.userOverrideType)

        let imageItem = try repository.saveImage(
            StoredClipboardImage(
                fileURL: URL(fileURLWithPath: "/tmp/ocr-image.png"),
                thumbnailURL: URL(fileURLWithPath: "/tmp/ocr-image-thumb.png"),
                contentHash: "ocr-image-hash",
                fileSize: 100,
                width: 10,
                height: 10,
                format: .png
            ),
            sourceApp: nil,
            sourceBundleID: nil
        )
        let ocrDate = Date(timeIntervalSince1970: 1_700_000_120)
        let ocrDetection = ContentDetectionResult(type: .plainText, confidence: 0.7, version: 4, detectedAt: ocrDate)

        try repository.saveOCRResult(id: imageItem.id, text: "recognized image text", detection: ocrDetection)

        let updatedImageItem = try historyItem(id: imageItem.id)
        XCTAssertEqual(updatedImageItem.contentType, .image)
        XCTAssertEqual(updatedImageItem.ocrStatus, .recognized)
        XCTAssertEqual(updatedImageItem.ocrText, "recognized image text")
        XCTAssertEqual(updatedImageItem.searchableText, "recognized image text")
        XCTAssertEqual(updatedImageItem.detectedType, .plainText)
        XCTAssertEqual(updatedImageItem.ocrUpdatedAt, ocrDate)
        XCTAssertNil(updatedImageItem.ocrErrorCode)
    }

    func testMarkOCRFailure_preservesRecognizedTextAndStoresErrorCode() throws {
        let item = try repository.saveText("ocr source", sourceApp: nil, sourceBundleID: nil)
        let recognizedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try repository.saveOCRResult(
            id: item.id,
            text: "previous recognition",
            detection: ContentDetectionResult(type: .plainText, confidence: 0.9, version: 1, detectedAt: recognizedAt)
        )
        let failureDate = Date(timeIntervalSince1970: 1_700_000_060)

        try repository.markOCRFailure(id: item.id, errorCode: "vision_unavailable", at: failureDate)

        let updatedItem = try historyItem(id: item.id)
        XCTAssertEqual(updatedItem.ocrStatus, .failed)
        XCTAssertEqual(updatedItem.ocrText, "previous recognition")
        XCTAssertEqual(updatedItem.ocrErrorCode, "vision_unavailable")
        XCTAssertEqual(updatedItem.ocrUpdatedAt, failureDate)
    }

    func testSaveDerivedText_createsMetadataAndKeepsSourceReferenceBehavior() throws {
        let source = try repository.saveText("original source", sourceApp: nil, sourceBundleID: nil)
        let request = derivedRequest(text: "derived output", sourceHistoryID: source.id)

        let derived = try repository.saveDerivedText(request)

        XCTAssertEqual(derived.contentType, .text)
        XCTAssertEqual(derived.textContent, "derived output")
        XCTAssertEqual(derived.derivedFromHistoryID, source.id)
        XCTAssertEqual(derived.derivedActionID, "format-json")
        XCTAssertEqual(derived.derivedActionSummary, "Decode Base64 → Format JSON 'result'")
        XCTAssertEqual(derived.derivedSourcePreview, "original source")
        XCTAssertEqual(derived.derivedSourceHash, "source-hash")
        XCTAssertEqual(derived.reuseCopyCount, 0)
        XCTAssertEqual(derived.pasteCount, 0)

        try repository.deleteItem(id: source.id)

        let afterSourceDelete = try historyItem(id: derived.id)
        XCTAssertNil(afterSourceDelete.derivedFromHistoryID)
        XCTAssertEqual(afterSourceDelete.derivedActionSummary, "Decode Base64 → Format JSON 'result'")
        XCTAssertEqual(afterSourceDelete.derivedSourcePreview, "original source")
        XCTAssertEqual(afterSourceDelete.derivedSourceHash, "source-hash")
    }

    func testSaveDerivedText_whenHashMatchesCanonicalRecord_reusesItWithoutOverwritingProvenance() throws {
        let source = try repository.saveText("source", sourceApp: nil, sourceBundleID: nil)
        let canonical = try repository.saveText(
            "same derived output",
            sourceApp: "Canonical App",
            sourceBundleID: "com.example.canonical"
        )

        let result = try repository.saveDerivedText(derivedRequest(text: "same derived output", sourceHistoryID: source.id))

        XCTAssertEqual(result.id, canonical.id)
        XCTAssertNil(result.derivedFromHistoryID)
        XCTAssertNil(result.derivedActionID)
        XCTAssertEqual(result.captureCount, canonical.captureCount + 1)
        XCTAssertEqual(result.sourceApp, AppBrand.displayName)
        XCTAssertEqual(result.sourceBundleID, Bundle.main.bundleIdentifier)
        XCTAssertEqual(try repository.fetchHistory(query: HistoryQuery(contentType: .text)).count, 2)
    }

    private func historyItem(id: Int64) throws -> ClipboardHistoryItem {
        try XCTUnwrap(repository.fetchHistory(query: HistoryQuery()).first { $0.id == id })
    }

    private func derivedRequest(text: String, sourceHistoryID: Int64) -> DerivedClipboardRecordRequest {
        DerivedClipboardRecordRequest(
            text: text,
            sourceHistoryID: sourceHistoryID,
            actionID: "format-json",
            actionSummary: "Decode Base64 → Format JSON 'result'",
            sourcePreview: "original source",
            sourceHash: "source-hash",
            detection: ContentDetectionResult(
                type: .json,
                confidence: 0.95,
                version: 2,
                detectedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
    }
}
