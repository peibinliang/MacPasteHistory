import XCTest
@testable import MacPasteHistory

final class ClipboardHistoryItemTests: XCTestCase {
    func testEffectiveDetectedType_prefersUserOverrideThenDetectionThenContentFallback() {
        XCTAssertEqual(makeItem(userOverrideType: .url, detectedType: .json).effectiveDetectedType, .url)
        XCTAssertEqual(makeItem(detectedType: .json).effectiveDetectedType, .json)
        XCTAssertEqual(makeItem(contentType: .image).effectiveDetectedType, .image)
        XCTAssertEqual(makeItem().effectiveDetectedType, .plainText)
    }

    func testDisplayDate_prefersLastCapturedAtAndFallsBackToCreatedAt() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let lastCapturedAt = Date(timeIntervalSince1970: 200)

        XCTAssertEqual(makeItem(createdAt: createdAt, lastCapturedAt: lastCapturedAt).displayDate, lastCapturedAt)
        XCTAssertEqual(makeItem(createdAt: createdAt).displayDate, createdAt)
    }

    func testIsDerived_whenActionIDExists_returnsTrue() {
        XCTAssertTrue(makeItem(derivedActionID: "summarize").isDerived)
        XCTAssertFalse(makeItem().isDerived)
    }

    func testDetectionResult_clampsConfidenceToSupportedRange() {
        XCTAssertEqual(ContentDetectionResult(type: .json, confidence: -0.2, version: 1, detectedAt: .now).confidence, 0)
        XCTAssertEqual(ContentDetectionResult(type: .json, confidence: 1.2, version: 1, detectedAt: .now).confidence, 1)
    }

    private func makeItem(
        contentType: ClipboardContentType = .text,
        userOverrideType: DetectedContentType? = nil,
        detectedType: DetectedContentType? = nil,
        createdAt: Date = .now,
        lastCapturedAt: Date? = nil,
        derivedActionID: String? = nil
    ) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: 1,
            contentType: contentType,
            textContent: "sample",
            filePath: nil,
            thumbnailPath: nil,
            sourceApp: nil,
            sourceBundleID: nil,
            contentHash: "hash",
            textLength: 6,
            fileSize: nil,
            imageWidth: nil,
            imageHeight: nil,
            imageFormat: nil,
            isFavorite: false,
            isSensitive: false,
            createdAt: createdAt,
            updatedAt: createdAt,
            detectedType: detectedType,
            userOverrideType: userOverrideType,
            lastCapturedAt: lastCapturedAt,
            derivedActionID: derivedActionID
        )
    }
}
