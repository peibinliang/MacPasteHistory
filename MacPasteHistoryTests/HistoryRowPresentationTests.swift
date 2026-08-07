import XCTest

@testable import MacPasteHistory

final class HistoryRowPresentationTests: XCTestCase {
    func testPresentation_formatsTextAndImagePreviewsMetadataAndAccessibility() {
        let text = item(id: 1, contentType: .text, text: "line one\nline two", sourceApp: "Notes")
        let image = item(
            id: 2,
            contentType: .image,
            text: "",
            sourceApp: nil,
            fileSize: 2_048,
            imageWidth: 40,
            imageHeight: 30,
            isFavorite: true
        )

        let textPresentation = HistoryRowPresentation(item: text, isSelected: true)
        let imagePresentation = HistoryRowPresentation(item: image, isSelected: false)

        XCTAssertEqual(textPresentation.previewText, "line one\nline two")
        XCTAssertTrue(textPresentation.metadataTitle.contains(L10n.string("Text")))
        XCTAssertTrue(textPresentation.metadataTitle.contains("Notes"))
        XCTAssertEqual(textPresentation.favoriteTitle, L10n.string("Favorite"))
        XCTAssertEqual(textPresentation.selectedRowHint, L10n.string("Click to paste into the previous app"))
        XCTAssertEqual(imagePresentation.previewText, String(format: L10n.string("Image %lldx%lld"), 40, 30))
        XCTAssertEqual(imagePresentation.sizeTitle, ByteCountFormatter.string(fromByteCount: 2_048, countStyle: .file))
        XCTAssertEqual(imagePresentation.favoriteTitle, L10n.string("Unfavorite"))
        XCTAssertNil(imagePresentation.selectedRowHint)
    }

    private func item(
        id: Int64,
        contentType: ClipboardContentType,
        text: String,
        sourceApp: String?,
        fileSize: Int? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        isFavorite: Bool = false
    ) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: id,
            contentType: contentType,
            textContent: text,
            filePath: nil,
            thumbnailPath: nil,
            sourceApp: sourceApp,
            sourceBundleID: nil,
            contentHash: "row-\(id)",
            textLength: text.count,
            fileSize: fileSize,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            imageFormat: nil,
            isFavorite: isFavorite,
            isSensitive: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
