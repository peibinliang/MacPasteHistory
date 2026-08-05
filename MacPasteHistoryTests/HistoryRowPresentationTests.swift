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

        XCTAssertEqual(textPresentation.previewText, "line one line two")
        XCTAssertTrue(textPresentation.metadataTitle.contains("Text"))
        XCTAssertTrue(textPresentation.metadataTitle.contains("Notes"))
        XCTAssertEqual(textPresentation.favoriteTitle, "Favorite")
        XCTAssertEqual(textPresentation.selectedRowHint, "Click to paste into the previous app")
        XCTAssertEqual(imagePresentation.previewText, "Image 40x30")
        XCTAssertEqual(imagePresentation.sizeTitle, "2 KB")
        XCTAssertEqual(imagePresentation.favoriteTitle, "Unfavorite")
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
