import XCTest

@testable import MacPasteHistory

final class DerivedSourcePreviewBuilderTests: XCTestCase {
    func testBuild_usesPrivacyAndContentSpecificStablePreviews() {
        XCTAssertEqual(DerivedSourcePreviewBuilder.build(for: item(isSensitive: true, text: "private")), "Sensitive content")
        XCTAssertEqual(DerivedSourcePreviewBuilder.build(for: item(contentType: .image)), "Image")
        XCTAssertEqual(
            DerivedSourcePreviewBuilder.build(for: item(text: "header.payload.signature", detectedType: .jwt, hash: "12345678abcdef")),
            "JWT • 12345678"
        )
        XCTAssertEqual(
            DerivedSourcePreviewBuilder.build(for: item(text: "https://example.com/path?q=private#anchor", detectedType: .url)),
            "https://example.com/path"
        )
    }

    func testBuild_collapsesTextWhitespaceTruncatesAt120CharactersAndHandlesEmptyText() {
        XCTAssertEqual(DerivedSourcePreviewBuilder.build(for: item(text: "  alpha\n\t beta   gamma  ")), "alpha beta gamma")
        XCTAssertEqual(DerivedSourcePreviewBuilder.build(for: item(text: "\n\t  ")), "Empty text")

        let longText = String(repeating: "a", count: 121)
        XCTAssertEqual(DerivedSourcePreviewBuilder.build(for: item(text: longText)), String(repeating: "a", count: 120))
    }

    private func item(
        contentType: ClipboardContentType = .text,
        isSensitive: Bool = false,
        text: String = "sample",
        detectedType: DetectedContentType? = nil,
        hash: String = "content-hash"
    ) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: 1,
            contentType: contentType,
            textContent: text,
            filePath: nil,
            thumbnailPath: nil,
            sourceApp: nil,
            sourceBundleID: nil,
            contentHash: hash,
            textLength: text.count,
            fileSize: nil,
            imageWidth: nil,
            imageHeight: nil,
            imageFormat: nil,
            isFavorite: false,
            isSensitive: isSensitive,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            detectedType: detectedType
        )
    }
}
