import XCTest
@testable import MacPasteHistory

final class ClipboardHistoryRepositoryTests: XCTestCase {
    private var databaseURL: URL!
    private var database: DatabaseConnection!
    private var repository: ClipboardHistoryRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        database = try DatabaseConnection(databaseURL: databaseURL)
        try MigrationManager(database: database).migrate()
        repository = ClipboardHistoryRepository(database: database)
    }

    override func tearDownWithError() throws {
        repository = nil
        try database?.close()
        database = nil
        if let databaseURL {
            try? FileManager.default.removeItem(at: databaseURL)
        }
        databaseURL = nil
        try super.tearDownWithError()
    }

    func testSaveText_whenContentIsNew_shouldPersistRecordWithHashAndLength() throws {
        let item = try repository.saveText("hello clipboard", sourceApp: "Notes", sourceBundleID: "com.apple.Notes")

        XCTAssertEqual(item.textContent, "hello clipboard")
        XCTAssertEqual(item.textLength, 15)
        XCTAssertEqual(item.sourceApp, "Notes")
        XCTAssertEqual(item.sourceBundleID, "com.apple.Notes")
        XCTAssertFalse(item.contentHash.isEmpty)
    }

    func testSaveText_whenContentIsDuplicated_shouldUpdateExistingRecordInsteadOfCreatingDuplicate() throws {
        let firstItem = try repository.saveText("duplicate text", sourceApp: nil, sourceBundleID: nil)
        Thread.sleep(forTimeInterval: 0.01)

        let secondItem = try repository.saveText("duplicate text", sourceApp: nil, sourceBundleID: nil)
        let items = try repository.fetchTextHistory(matching: nil)

        XCTAssertEqual(firstItem.id, secondItem.id)
        XCTAssertEqual(items.count, 1)
    }

    func testFetchTextHistory_whenKeywordProvided_shouldReturnMatchingRecords() throws {
        _ = try repository.saveText("alpha note", sourceApp: nil, sourceBundleID: nil)
        _ = try repository.saveText("beta memo", sourceApp: nil, sourceBundleID: nil)

        let items = try repository.fetchTextHistory(matching: "alpha")

        XCTAssertEqual(items.map(\.textContent), ["alpha note"])
    }

    func testDeleteTextHistoryItem_shouldRemoveSelectedRecord() throws {
        let item = try repository.saveText("delete me", sourceApp: nil, sourceBundleID: nil)

        try repository.deleteItem(id: item.id)

        XCTAssertTrue(try repository.fetchTextHistory(matching: nil).isEmpty)
    }

    func testSetFavorite_whenRecordExists_shouldPersistFavoriteState() throws {
        let item = try repository.saveText("favorite me", sourceApp: nil, sourceBundleID: nil)

        try repository.setFavorite(true, id: item.id)
        let items = try repository.fetchHistory(query: HistoryQuery(favoritesOnly: true))

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, item.id)
        XCTAssertEqual(items.first?.isFavorite, true)
    }

    func testSetFavorite_whenFavoriteIsRemoved_shouldRemoveFromFavoritesQuery() throws {
        let item = try repository.saveText("unfavorite me", sourceApp: nil, sourceBundleID: nil)

        try repository.setFavorite(true, id: item.id)
        try repository.setFavorite(false, id: item.id)

        XCTAssertTrue(try repository.fetchHistory(query: HistoryQuery(favoritesOnly: true)).isEmpty)
    }

    func testFetchHistory_whenContentTypeIsText_shouldReturnOnlyTextRecords() throws {
        _ = try repository.saveText("text only", sourceApp: nil, sourceBundleID: nil)

        let textItems = try repository.fetchHistory(query: HistoryQuery(contentType: .text))
        let imageItems = try repository.fetchHistory(query: HistoryQuery(contentType: .image))

        XCTAssertEqual(textItems.map(\.textContent), ["text only"])
        XCTAssertTrue(imageItems.isEmpty)
    }

    func testFetchHistory_whenLimitAndOffsetProvided_shouldReturnRequestedPage() throws {
        _ = try repository.saveText("first", sourceApp: nil, sourceBundleID: nil)
        Thread.sleep(forTimeInterval: 0.01)
        _ = try repository.saveText("second", sourceApp: nil, sourceBundleID: nil)
        Thread.sleep(forTimeInterval: 0.01)
        _ = try repository.saveText("third", sourceApp: nil, sourceBundleID: nil)

        let firstPage = try repository.fetchHistory(query: HistoryQuery(limit: 2, offset: 0))
        let secondPage = try repository.fetchHistory(query: HistoryQuery(limit: 2, offset: 2))

        XCTAssertEqual(firstPage.map(\.textContent), ["third", "second"])
        XCTAssertEqual(secondPage.map(\.textContent), ["first"])
    }

    func testSaveImage_whenContentIsNew_shouldPersistPathsAndMetadata() throws {
        let storedImage = StoredClipboardImage(
            fileURL: URL(fileURLWithPath: "/tmp/original.png"),
            thumbnailURL: URL(fileURLWithPath: "/tmp/thumb.png"),
            contentHash: "image-hash-1",
            fileSize: 1234,
            width: 80,
            height: 60,
            format: .png
        )

        let item = try repository.saveImage(storedImage, sourceApp: "Preview", sourceBundleID: "com.apple.Preview")

        XCTAssertEqual(item.contentType, .image)
        XCTAssertEqual(item.filePath, "/tmp/original.png")
        XCTAssertEqual(item.thumbnailPath, "/tmp/thumb.png")
        XCTAssertEqual(item.fileSize, 1234)
        XCTAssertEqual(item.imageWidth, 80)
        XCTAssertEqual(item.imageHeight, 60)
        XCTAssertEqual(item.imageFormat, .png)
        XCTAssertEqual(item.sourceApp, "Preview")
    }

    func testSaveImage_whenContentIsDuplicated_shouldUpdateExistingRecordInsteadOfCreatingDuplicate() throws {
        let firstImage = StoredClipboardImage(
            fileURL: URL(fileURLWithPath: "/tmp/first.png"),
            thumbnailURL: URL(fileURLWithPath: "/tmp/first-thumb.png"),
            contentHash: "same-image-hash",
            fileSize: 100,
            width: 10,
            height: 10,
            format: .png
        )
        let secondImage = StoredClipboardImage(
            fileURL: URL(fileURLWithPath: "/tmp/second.png"),
            thumbnailURL: URL(fileURLWithPath: "/tmp/second-thumb.png"),
            contentHash: "same-image-hash",
            fileSize: 100,
            width: 10,
            height: 10,
            format: .png
        )

        let firstItem = try repository.saveImage(firstImage, sourceApp: nil, sourceBundleID: nil)
        let secondItem = try repository.saveImage(secondImage, sourceApp: nil, sourceBundleID: nil)
        let imageItems = try repository.fetchHistory(query: HistoryQuery(contentType: .image))

        XCTAssertEqual(firstItem.id, secondItem.id)
        XCTAssertEqual(imageItems.count, 1)
        XCTAssertEqual(imageItems.first?.filePath, "/tmp/second.png")
    }
}
