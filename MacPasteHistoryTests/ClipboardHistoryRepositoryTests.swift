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

    func testFetchHistory_whenTimeRangeProvided_shouldReturnItemsInsideRange() throws {
        let oldItem = try repository.saveText("old note", sourceApp: "Notes", sourceBundleID: "com.apple.Notes")
        _ = try repository.saveText("new note", sourceApp: "Notes", sourceBundleID: "com.apple.Notes")
        try database.execute("UPDATE clipboard_history SET created_at = '2001-01-01 00:00:00' WHERE id = \(oldItem.id);")

        let items = try repository.fetchHistory(query: HistoryQuery(timeRange: .last7Days))

        XCTAssertEqual(items.map(\.textContent), ["new note"])
    }

    func testFetchHistory_whenSourceBundleProvided_shouldReturnMatchingSource() throws {
        _ = try repository.saveText("safari note", sourceApp: "Safari", sourceBundleID: "com.apple.Safari")
        _ = try repository.saveText("notes note", sourceApp: "Notes", sourceBundleID: "com.apple.Notes")

        let items = try repository.fetchHistory(
            query: HistoryQuery(sourceFilter: HistoryQuery.SourceFilter(appName: "Safari", bundleID: "com.apple.Safari"))
        )

        XCTAssertEqual(items.map(\.textContent), ["safari note"])
    }

    func testFetchHistory_whenFiltersComposed_shouldRequireAllCriteria() throws {
        let favorite = try repository.saveText("alpha favorite", sourceApp: "Safari", sourceBundleID: "com.apple.Safari")
        _ = try repository.saveText("alpha ordinary", sourceApp: "Notes", sourceBundleID: "com.apple.Notes")
        try repository.setFavorite(true, id: favorite.id)

        let items = try repository.fetchHistory(
            query: HistoryQuery(
                keyword: "alpha",
                favoritesOnly: true,
                contentType: .text,
                timeRange: .last30Days,
                sourceFilter: HistoryQuery.SourceFilter(appName: "Safari", bundleID: "com.apple.Safari")
            )
        )

        XCTAssertEqual(items.map(\.textContent), ["alpha favorite"])
    }

    func testFetchSourceOptions_shouldReturnDistinctKnownSources() throws {
        _ = try repository.saveText("unknown", sourceApp: nil, sourceBundleID: nil)
        _ = try repository.saveText("safari", sourceApp: "Safari", sourceBundleID: "com.apple.Safari")

        let options = try repository.fetchSourceOptions()

        XCTAssertFalse(options.contains(HistorySourceOption(appName: nil, bundleID: nil)))
        XCTAssertTrue(options.contains(HistorySourceOption(appName: "Safari", bundleID: "com.apple.Safari")))
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

    func testFetchHistory_whenV3MetadataExists_shouldMapEveryNewField() throws {
        let source = try repository.saveText("source record", sourceApp: nil, sourceBundleID: nil)
        let item = try repository.saveText("derived record", sourceApp: nil, sourceBundleID: nil)
        try database.execute("""
        UPDATE clipboard_history SET
            searchable_text = 'searchable derived record',
            detected_type = 'json',
            user_override_type = 'url',
            detection_confidence = 0.75,
            detection_version = 3,
            detected_at = '2026-08-05 01:02:03',
            first_captured_at = '2026-08-01 01:02:03',
            last_captured_at = '2026-08-05 04:05:06',
            capture_count = 7,
            reuse_copy_count = 4,
            paste_count = 2,
            last_reuse_copied_at = NULL,
            last_pasted_at = '2026-08-05 05:06:07',
            ocr_status = 'recognized',
            ocr_text = 'recognized text',
            ocr_updated_at = NULL,
            ocr_error_code = 'none',
            derived_from_history_id = \(source.id),
            derived_action_id = 'summarize',
            derived_action_summary = 'Summarized source',
            derived_at = '2026-08-05 06:07:08',
            derived_source_preview = 'source preview',
            derived_source_hash = 'source-hash'
        WHERE id = \(item.id);
        """)

        let reloaded = try XCTUnwrap(repository.fetchHistory(query: HistoryQuery()).first { $0.id == item.id })

        XCTAssertEqual(reloaded.searchableText, "searchable derived record")
        XCTAssertEqual(reloaded.detectedType, .json)
        XCTAssertEqual(reloaded.userOverrideType, .url)
        XCTAssertEqual(reloaded.detectionConfidence, 0.75)
        XCTAssertEqual(reloaded.detectionVersion, 3)
        XCTAssertEqual(reloaded.captureCount, 7)
        XCTAssertEqual(reloaded.reuseCopyCount, 4)
        XCTAssertEqual(reloaded.pasteCount, 2)
        XCTAssertEqual(reloaded.ocrStatus, .recognized)
        XCTAssertEqual(reloaded.ocrText, "recognized text")
        XCTAssertEqual(reloaded.ocrErrorCode, "none")
        XCTAssertEqual(reloaded.derivedFromHistoryID, source.id)
        XCTAssertEqual(reloaded.derivedActionID, "summarize")
        XCTAssertEqual(reloaded.derivedActionSummary, "Summarized source")
        XCTAssertEqual(reloaded.derivedSourcePreview, "source preview")
        XCTAssertEqual(reloaded.derivedSourceHash, "source-hash")
        XCTAssertNil(reloaded.lastReuseCopiedAt)
        XCTAssertNil(reloaded.ocrUpdatedAt)
        XCTAssertEqual(reloaded.detectedAt, Self.date("2026-08-05 01:02:03"))
        XCTAssertEqual(reloaded.firstCapturedAt, Self.date("2026-08-01 01:02:03"))
        XCTAssertEqual(reloaded.lastCapturedAt, Self.date("2026-08-05 04:05:06"))
        XCTAssertEqual(reloaded.lastPastedAt, Self.date("2026-08-05 05:06:07"))
        XCTAssertEqual(reloaded.derivedAt, Self.date("2026-08-05 06:07:08"))
    }

    func testFetchHistory_whenV3ValuesAreInvalid_shouldDecodeSafely() throws {
        let item = try repository.saveText("invalid metadata", sourceApp: nil, sourceBundleID: nil)
        try database.execute("""
        UPDATE clipboard_history SET
            detected_type = 'not-a-real-type',
            user_override_type = 'also-invalid',
            detection_confidence = 'not-a-number',
            detected_at = 'not-a-date',
            ocr_status = 'unknown-status'
        WHERE id = \(item.id);
        """)

        let reloaded = try XCTUnwrap(repository.fetchHistory(query: HistoryQuery()).first { $0.id == item.id })

        XCTAssertNil(reloaded.detectedType)
        XCTAssertNil(reloaded.userOverrideType)
        XCTAssertNil(reloaded.detectionConfidence)
        XCTAssertNil(reloaded.detectedAt)
        XCTAssertEqual(reloaded.ocrStatus, .notStarted)
    }

    private static func date(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }
}
