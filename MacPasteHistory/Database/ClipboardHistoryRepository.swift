import Foundation
import SQLite3

final class ClipboardHistoryRepository {
    private let database: DatabaseConnection
    private let hashService: TextHashService
    private let dateFormatter: DateFormatter

    init(database: DatabaseConnection, hashService: TextHashService = TextHashService()) {
        self.database = database
        self.hashService = hashService
        self.dateFormatter = DateFormatter.sqliteDateFormatter
    }

    func saveText(_ text: String, sourceApp: String?, sourceBundleID: String?) throws -> ClipboardHistoryItem {
        let normalizedText = hashService.normalize(text)
        let contentHash = hashService.hash(for: normalizedText)

        return try database.inTransaction {
            if let existingItem = try fetchItem(contentHash: contentHash) {
                try updateDuplicateTextItem(id: existingItem.id, sourceApp: sourceApp, sourceBundleID: sourceBundleID)
                try insertCaptureEvent(historyID: existingItem.id, sourceApp: sourceApp, sourceBundleID: sourceBundleID)
                guard let updatedItem = try fetchItem(id: existingItem.id) else {
                    throw DatabaseError.stepFailed("Updated text history item could not be reloaded")
                }
                return updatedItem
            }

            let statement = try database.prepare(
                """
                INSERT INTO clipboard_history (
                    content_type,
                    text_content,
                    source_app,
                    source_bundle_id,
                    content_hash,
                    text_length,
                    searchable_text,
                    first_captured_at,
                    last_captured_at,
                    capture_count
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 1);
                """
            )
            defer { sqlite3_finalize(statement) }

            try bindText(ClipboardContentType.text.rawValue, to: statement, index: 1)
            try bindText(normalizedText, to: statement, index: 2)
            try bindNullableText(sourceApp, to: statement, index: 3)
            try bindNullableText(sourceBundleID, to: statement, index: 4)
            try bindText(contentHash, to: statement, index: 5)
            try bindInt(normalizedText.count, to: statement, index: 6)
            try bindText(normalizedText, to: statement, index: 7)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.stepFailed(database.lastErrorMessage)
            }

            let itemID = database.lastInsertedRowID
            try insertCaptureEvent(historyID: itemID, sourceApp: sourceApp, sourceBundleID: sourceBundleID)
            guard let item = try fetchItem(id: itemID) else {
                throw DatabaseError.stepFailed("Inserted text history item could not be loaded")
            }
            return item
        }
    }

    func fetchTextHistory(matching keyword: String?) throws -> [ClipboardHistoryItem] {
        try fetchHistory(query: HistoryQuery(keyword: keyword, contentType: .text))
    }

    func fetchCaptureEvents(historyID: Int64, since date: Date) throws -> [ClipboardCaptureEvent] {
        let statement = try database.prepare(
            """
            SELECT id, history_id, source_app, source_bundle_id, captured_at
            FROM clipboard_capture_events
            WHERE history_id = ? AND datetime(captured_at) >= datetime(?)
            ORDER BY datetime(captured_at) DESC, id DESC;
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindInt64(historyID, to: statement, index: 1)
        try bindText(dateFormatter.string(from: date), to: statement, index: 2)

        var events: [ClipboardCaptureEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let capturedAtValue = stringValue(statement, index: 4)
            guard let capturedAt = dateFormatter.date(from: capturedAtValue) else {
                throw DatabaseError.invalidDate(capturedAtValue)
            }
            events.append(
                ClipboardCaptureEvent(
                    id: sqlite3_column_int64(statement, 0),
                    historyID: sqlite3_column_int64(statement, 1),
                    sourceApp: nullableStringValue(statement, index: 2),
                    sourceBundleID: nullableStringValue(statement, index: 3),
                    capturedAt: capturedAt
                )
            )
        }
        return events
    }

    func fetchCaptureSummaries(historyID: Int64) throws -> [ClipboardCaptureEventSummary] {
        let statement = try database.prepare(
            """
            SELECT id, history_id, source_key, source_app, source_bundle_id,
                   capture_count, first_captured_at, last_captured_at
            FROM clipboard_capture_event_summaries
            WHERE history_id = ?
            ORDER BY datetime(last_captured_at) DESC, id DESC;
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindInt64(historyID, to: statement, index: 1)
        var summaries: [ClipboardCaptureEventSummary] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let firstCapturedAtValue = stringValue(statement, index: 6)
            let lastCapturedAtValue = stringValue(statement, index: 7)
            guard let firstCapturedAt = dateFormatter.date(from: firstCapturedAtValue) else {
                throw DatabaseError.invalidDate(firstCapturedAtValue)
            }
            guard let lastCapturedAt = dateFormatter.date(from: lastCapturedAtValue) else {
                throw DatabaseError.invalidDate(lastCapturedAtValue)
            }
            summaries.append(
                ClipboardCaptureEventSummary(
                    id: sqlite3_column_int64(statement, 0),
                    historyID: sqlite3_column_int64(statement, 1),
                    sourceKey: stringValue(statement, index: 2),
                    sourceApp: nullableStringValue(statement, index: 3),
                    sourceBundleID: nullableStringValue(statement, index: 4),
                    captureCount: Int(sqlite3_column_int(statement, 5)),
                    firstCapturedAt: firstCapturedAt,
                    lastCapturedAt: lastCapturedAt
                )
            )
        }
        return summaries
    }

    func aggregateCaptureEvents(before cutoff: Date) throws {
        try database.inTransaction {
            let aggregates = try captureEventAggregates(before: cutoff)
            for aggregate in aggregates.values {
                try upsertCaptureEventSummary(aggregate)
            }
            try deleteCaptureEvents(before: cutoff)
        }
    }

    func saveImage(
        _ image: StoredClipboardImage,
        sourceApp: String?,
        sourceBundleID: String?
    ) throws -> ClipboardHistoryItem {
        return try database.inTransaction {
            if let existingItem = try fetchItem(contentHash: image.contentHash) {
                try updateDuplicateImageItem(
                    id: existingItem.id,
                    image: image,
                    sourceApp: sourceApp,
                    sourceBundleID: sourceBundleID
                )
                try insertCaptureEvent(historyID: existingItem.id, sourceApp: sourceApp, sourceBundleID: sourceBundleID)
                guard let updatedItem = try fetchItem(id: existingItem.id) else {
                    throw DatabaseError.stepFailed("Updated image history item could not be reloaded")
                }
                return updatedItem
            }

            let statement = try database.prepare(
                """
                INSERT INTO clipboard_history (
                    content_type,
                    file_path,
                    thumbnail_path,
                    source_app,
                    source_bundle_id,
                    content_hash,
                    file_size,
                    image_width,
                    image_height,
                    image_format,
                    searchable_text,
                    first_captured_at,
                    last_captured_at,
                    capture_count
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 1);
                """
            )
            defer { sqlite3_finalize(statement) }

            try bindText(ClipboardContentType.image.rawValue, to: statement, index: 1)
            try bindText(image.fileURL.path, to: statement, index: 2)
            try bindText(image.thumbnailURL.path, to: statement, index: 3)
            try bindNullableText(sourceApp, to: statement, index: 4)
            try bindNullableText(sourceBundleID, to: statement, index: 5)
            try bindText(image.contentHash, to: statement, index: 6)
            try bindInt(image.fileSize, to: statement, index: 7)
            try bindInt(image.width, to: statement, index: 8)
            try bindInt(image.height, to: statement, index: 9)
            try bindText(image.format.rawValue, to: statement, index: 10)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.stepFailed(database.lastErrorMessage)
            }

            let itemID = database.lastInsertedRowID
            try insertCaptureEvent(historyID: itemID, sourceApp: sourceApp, sourceBundleID: sourceBundleID)
            guard let item = try fetchItem(id: itemID) else {
                throw DatabaseError.stepFailed("Inserted image history item could not be loaded")
            }
            return item
        }
    }

    func recordReuseCopy(historyID: Int64, at date: Date) throws {
        try updateUsage(
            historyID: historyID,
            countColumn: "reuse_copy_count",
            timestampColumn: "last_reuse_copied_at",
            at: date
        )
    }

    func recordPaste(historyID: Int64, at date: Date) throws {
        try updateUsage(
            historyID: historyID,
            countColumn: "paste_count",
            timestampColumn: "last_pasted_at",
            at: date
        )
    }

    func updateDetectedType(id: Int64, result: ContentDetectionResult) throws {
        let statement = try database.prepare(
            """
            UPDATE clipboard_history
            SET detected_type = ?,
                detection_confidence = ?,
                detection_version = ?,
                detected_at = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?;
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindText(result.type.rawValue, to: statement, index: 1)
        try bindDouble(result.confidence, to: statement, index: 2)
        try bindInt(result.version, to: statement, index: 3)
        try bindText(dateFormatter.string(from: result.detectedAt), to: statement, index: 4)
        try bindInt64(id, to: statement, index: 5)
        try stepUpdate(statement)
    }

    func updateUserOverrideType(id: Int64, type: DetectedContentType?) throws {
        let statement = try database.prepare(
            """
            UPDATE clipboard_history
            SET user_override_type = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?;
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindNullableText(type?.rawValue, to: statement, index: 1)
        try bindInt64(id, to: statement, index: 2)
        try stepUpdate(statement)
    }

    func saveOCRResult(id: Int64, text: String, detection: ContentDetectionResult) throws {
        let statement = try database.prepare(
            """
            UPDATE clipboard_history
            SET ocr_status = ?,
                ocr_text = ?,
                ocr_updated_at = ?,
                ocr_error_code = NULL,
                searchable_text = ?,
                detected_type = ?,
                detection_confidence = ?,
                detection_version = ?,
                detected_at = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?;
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindText(OCRStatus.recognized.rawValue, to: statement, index: 1)
        try bindText(text, to: statement, index: 2)
        try bindText(dateFormatter.string(from: detection.detectedAt), to: statement, index: 3)
        try bindText(text, to: statement, index: 4)
        try bindText(detection.type.rawValue, to: statement, index: 5)
        try bindDouble(detection.confidence, to: statement, index: 6)
        try bindInt(detection.version, to: statement, index: 7)
        try bindText(dateFormatter.string(from: detection.detectedAt), to: statement, index: 8)
        try bindInt64(id, to: statement, index: 9)
        try stepUpdate(statement)
    }

    func markOCRFailure(id: Int64, errorCode: String, at date: Date) throws {
        let statement = try database.prepare(
            """
            UPDATE clipboard_history
            SET ocr_status = ?,
                ocr_error_code = ?,
                ocr_updated_at = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?;
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindText(OCRStatus.failed.rawValue, to: statement, index: 1)
        try bindText(errorCode, to: statement, index: 2)
        try bindText(dateFormatter.string(from: date), to: statement, index: 3)
        try bindInt64(id, to: statement, index: 4)
        try stepUpdate(statement)
    }

    func saveDerivedText(_ request: DerivedClipboardRecordRequest) throws -> ClipboardHistoryItem {
        let normalizedText = hashService.normalize(request.text)
        let contentHash = hashService.hash(for: normalizedText)
        let appBundleID = Bundle.main.bundleIdentifier

        return try database.inTransaction {
            if let existingItem = try fetchItem(contentHash: contentHash) {
                try updateDuplicateTextItem(
                    id: existingItem.id,
                    sourceApp: AppBrand.displayName,
                    sourceBundleID: appBundleID
                )
                try insertCaptureEvent(
                    historyID: existingItem.id,
                    sourceApp: AppBrand.displayName,
                    sourceBundleID: appBundleID
                )
                guard let updatedItem = try fetchItem(id: existingItem.id) else {
                    throw DatabaseError.stepFailed("Derived history item could not be reloaded")
                }
                return updatedItem
            }

            let statement = try database.prepare(
                """
                INSERT INTO clipboard_history (
                    content_type, text_content, source_app, source_bundle_id, content_hash, text_length,
                    searchable_text, detected_type, detection_confidence, detection_version, detected_at,
                    first_captured_at, last_captured_at, capture_count,
                    derived_from_history_id, derived_action_id, derived_action_summary, derived_at,
                    derived_source_preview, derived_source_hash
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 1,
                        ?, ?, ?, CURRENT_TIMESTAMP, ?, ?);
                """
            )
            defer { sqlite3_finalize(statement) }

            try bindText(ClipboardContentType.text.rawValue, to: statement, index: 1)
            try bindText(normalizedText, to: statement, index: 2)
            try bindText(AppBrand.displayName, to: statement, index: 3)
            try bindNullableText(appBundleID, to: statement, index: 4)
            try bindText(contentHash, to: statement, index: 5)
            try bindInt(normalizedText.count, to: statement, index: 6)
            try bindText(normalizedText, to: statement, index: 7)
            try bindText(request.detection.type.rawValue, to: statement, index: 8)
            try bindDouble(request.detection.confidence, to: statement, index: 9)
            try bindInt(request.detection.version, to: statement, index: 10)
            try bindText(dateFormatter.string(from: request.detection.detectedAt), to: statement, index: 11)
            try bindInt64(request.sourceHistoryID, to: statement, index: 12)
            try bindText(request.actionID, to: statement, index: 13)
            try bindText(request.actionSummary, to: statement, index: 14)
            try bindText(request.sourcePreview, to: statement, index: 15)
            try bindText(request.sourceHash, to: statement, index: 16)
            try stepUpdate(statement)

            let itemID = database.lastInsertedRowID
            try insertCaptureEvent(
                historyID: itemID,
                sourceApp: AppBrand.displayName,
                sourceBundleID: appBundleID
            )
            guard let item = try fetchItem(id: itemID) else {
                throw DatabaseError.stepFailed("Inserted derived history item could not be loaded")
            }
            return item
        }
    }

    func fetchHistory(query: HistoryQuery) throws -> [ClipboardHistoryItem] {
        let trimmedKeyword = query.keyword?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasKeyword = trimmedKeyword?.isEmpty == false
        let sql = historySQL(hasKeyword: hasKeyword, query: query)
        let statement = try database.prepare(sql)
        defer {
            sqlite3_finalize(statement)
        }

        var bindIndex: Int32 = 1
        if let contentType = query.contentType {
            try bindText(contentType.rawValue, to: statement, index: bindIndex)
            bindIndex += 1
        }
        if let trimmedKeyword, hasKeyword {
            try bindText("%\(trimmedKeyword)%", to: statement, index: bindIndex)
            bindIndex += 1
        }
        if let startDate = query.timeRange.startDate {
            try bindText(dateFormatter.string(from: startDate), to: statement, index: bindIndex)
            bindIndex += 1
        }
        if query.sourceFilter.isAll == false {
            if let bundleID = query.sourceFilter.bundleID {
                try bindText(bundleID, to: statement, index: bindIndex)
                bindIndex += 1
            } else if let appName = query.sourceFilter.appName {
                try bindText(appName, to: statement, index: bindIndex)
                bindIndex += 1
            }
        }
        try bindInt(query.limit, to: statement, index: bindIndex)
        try bindInt(query.offset, to: statement, index: bindIndex + 1)

        return try collectItems(from: statement)
    }

    func fetchSourceOptions() throws -> [HistorySourceOption] {
        let statement = try database.prepare(
            """
            SELECT source_app, source_bundle_id
            FROM clipboard_history
            WHERE source_app IS NOT NULL OR source_bundle_id IS NOT NULL
            GROUP BY source_app, source_bundle_id
            ORDER BY source_app COLLATE NOCASE ASC, source_bundle_id COLLATE NOCASE ASC;
            """
        )
        defer { sqlite3_finalize(statement) }

        var options: [HistorySourceOption] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            options.append(
                HistorySourceOption(
                    appName: nullableStringValue(statement, index: 0),
                    bundleID: nullableStringValue(statement, index: 1)
                )
            )
        }
        return options
    }

    func setFavorite(_ isFavorite: Bool, id: Int64) throws {
        let statement = try database.prepare(
            """
            UPDATE clipboard_history
            SET is_favorite = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?;
            """
        )
        defer {
            sqlite3_finalize(statement)
        }

        try bindInt(isFavorite ? 1 : 0, to: statement, index: 1)
        try bindInt64(id, to: statement, index: 2)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    func deleteItem(id: Int64) throws {
        let statement = try database.prepare("DELETE FROM clipboard_history WHERE id = ?;")
        defer {
            sqlite3_finalize(statement)
        }

        try bindInt64(id, to: statement, index: 1)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    func clearTextHistory() throws {
        try database.execute("DELETE FROM clipboard_history WHERE content_type = 'text';")
    }

    func clearAllHistory() throws {
        try database.execute("DELETE FROM clipboard_history;")
    }

    // MARK: - Data Cleanup

    /// Removes records older than `retentionDays`. Favorite records are preserved.
    func deleteExpiredRecords(retentionDays: Int) throws {
        guard retentionDays > 0 else { return }
        let sql = """
        DELETE FROM clipboard_history
        WHERE is_favorite = 0
          AND datetime(created_at) < datetime('now', '\(-retentionDays) days');
        """
        try database.execute(sql)
    }

    /// Returns expired image records so callers can remove files before deleting database rows.
    func expiredImageRecords(retentionDays: Int) throws -> [ClipboardHistoryItem] {
        guard retentionDays > 0 else { return [] }
        let sql = """
        \(Self.selectHistorySQL)
        WHERE content_type = ?
          AND is_favorite = 0
          AND datetime(created_at) < datetime('now', ?);
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }

        try bindText(ClipboardContentType.image.rawValue, to: statement, index: 1)
        try bindText("-\(retentionDays) days", to: statement, index: 2)

        return try collectItems(from: statement)
    }

    /// Returns IDs of text records exceeding `maxCount`, ordered oldest first (favorites preserved).
    func textRecordsExceeding(limit maxCount: Int) throws -> [Int64] {
        guard maxCount > 0 else { return [] }
        let nonFavoriteLimit = try max(0, maxCount - favoriteRecordCount(contentType: .text))
        let sql = """
        SELECT id FROM clipboard_history
        WHERE content_type = 'text' AND is_favorite = 0
        ORDER BY datetime(created_at) DESC, id DESC
        LIMIT -1 OFFSET ?;
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bindInt(nonFavoriteLimit, to: statement, index: 1)
        return try collectInt64Column(from: statement)
    }

    /// Returns image records exceeding `maxCount`, as full items (needed for file cleanup).
    func imageRecordsForEviction(limit maxCount: Int) throws -> [ClipboardHistoryItem] {
        guard maxCount > 0 else { return [] }
        let nonFavoriteLimit = try max(0, maxCount - favoriteRecordCount(contentType: .image))
        let sql = """
        SELECT id FROM clipboard_history
        WHERE content_type = 'image' AND is_favorite = 0
        ORDER BY datetime(created_at) DESC, id DESC
        LIMIT -1 OFFSET ?;
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bindInt(nonFavoriteLimit, to: statement, index: 1)
        let ids = try collectInt64Column(from: statement)
        return try ids.compactMap { try fetchItem(id: $0) }
    }

    /// Deletes records by ID. Used after fetching records that exceed limits.
    func deleteItems(withIDs ids: [Int64]) throws {
        for id in ids {
            try deleteItem(id: id)
        }
    }

    /// Returns image-type records beyond the configured storage cap, oldest first.
    /// The `maxStorageInBytes` parameter defines the ceiling; records beyond it are evicted.
    func imageRecordsBeyondStorage(maxStorageInBytes: Int) throws -> [ClipboardHistoryItem] {
        guard maxStorageInBytes > 0 else { return [] }
        // Fetch image records ordered by oldest first, compute running total to find eviction candidates.
        let sql = """
        SELECT id, file_size FROM clipboard_history
        WHERE content_type = 'image' AND is_favorite = 0
        ORDER BY datetime(created_at) ASC, id ASC;
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }

        var records: [(id: Int64, fileSize: Int)] = []
        var totalSize = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            let fileSize = Int(sqlite3_column_int(statement, 1))
            records.append((id: id, fileSize: fileSize))
            totalSize += fileSize
        }

        guard totalSize > maxStorageInBytes else { return [] }

        var runningSize = totalSize
        var idsToEvict: [Int64] = []
        for record in records where runningSize > maxStorageInBytes {
            idsToEvict.append(record.id)
            runningSize -= record.fileSize
        }

        return try idsToEvict.compactMap { try fetchItem(id: $0) }
    }

    /// Returns the total count of image records currently stored.
    func imageRecordCount() throws -> Int {
        let statement = try database.prepare(
            "SELECT COUNT(*) FROM clipboard_history WHERE content_type = 'image';"
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    /// Returns the total count of text records currently stored.
    func textRecordCount() throws -> Int {
        let statement = try database.prepare(
            "SELECT COUNT(*) FROM clipboard_history WHERE content_type = 'text';"
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func favoriteRecordCount(contentType: ClipboardContentType) throws -> Int {
        let statement = try database.prepare(
            "SELECT COUNT(*) FROM clipboard_history WHERE content_type = ? AND is_favorite = 1;"
        )
        defer { sqlite3_finalize(statement) }
        try bindText(contentType.rawValue, to: statement, index: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func collectInt64Column(from statement: OpaquePointer?) throws -> [Int64] {
        var results: [Int64] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(sqlite3_column_int64(statement, 0))
        }
        return results
    }

    private func historySQL(hasKeyword: Bool, query: HistoryQuery) -> String {
        var conditions: [String] = []
        if query.contentType != nil {
            conditions.append("content_type = ?")
        }
        if hasKeyword {
            conditions.append("text_content LIKE ?")
        }
        if query.favoritesOnly {
            conditions.append("is_favorite = 1")
        }
        if query.timeRange.startDate != nil {
            conditions.append("datetime(created_at) >= datetime(?)")
        }
        if query.sourceFilter.isAll == false {
            if query.sourceFilter.bundleID != nil {
                conditions.append("source_bundle_id = ?")
            } else if query.sourceFilter.appName != nil {
                conditions.append("source_app = ?")
            }
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        return """
        \(Self.selectHistorySQL)
        \(whereClause)
        ORDER BY datetime(created_at) DESC, id DESC
        LIMIT ? OFFSET ?;
        """
    }

    private func updateDuplicateTextItem(id: Int64, sourceApp: String?, sourceBundleID: String?) throws {
        let statement = try database.prepare(
            """
            UPDATE clipboard_history
            SET source_app = ?,
                source_bundle_id = ?,
                last_captured_at = CURRENT_TIMESTAMP,
                capture_count = capture_count + 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND content_type = ?;
            """
        )
        defer {
            sqlite3_finalize(statement)
        }

        try bindNullableText(sourceApp, to: statement, index: 1)
        try bindNullableText(sourceBundleID, to: statement, index: 2)
        try bindInt64(id, to: statement, index: 3)
        try bindText(ClipboardContentType.text.rawValue, to: statement, index: 4)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    private func updateUsage(
        historyID: Int64,
        countColumn: String,
        timestampColumn: String,
        at date: Date
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE clipboard_history
            SET \(countColumn) = \(countColumn) + 1,
                \(timestampColumn) = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?;
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindText(dateFormatter.string(from: date), to: statement, index: 1)
        try bindInt64(historyID, to: statement, index: 2)
        try stepUpdate(statement)
    }

    private func updateDuplicateImageItem(
        id: Int64,
        image: StoredClipboardImage,
        sourceApp: String?,
        sourceBundleID: String?
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE clipboard_history
            SET file_path = ?,
                thumbnail_path = ?,
                source_app = ?,
                source_bundle_id = ?,
                file_size = ?,
                image_width = ?,
                image_height = ?,
                image_format = ?,
                last_captured_at = CURRENT_TIMESTAMP,
                capture_count = capture_count + 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ? AND content_type = ?;
            """
        )
        defer {
            sqlite3_finalize(statement)
        }

        try bindText(image.fileURL.path, to: statement, index: 1)
        try bindText(image.thumbnailURL.path, to: statement, index: 2)
        try bindNullableText(sourceApp, to: statement, index: 3)
        try bindNullableText(sourceBundleID, to: statement, index: 4)
        try bindInt(image.fileSize, to: statement, index: 5)
        try bindInt(image.width, to: statement, index: 6)
        try bindInt(image.height, to: statement, index: 7)
        try bindText(image.format.rawValue, to: statement, index: 8)
        try bindInt64(id, to: statement, index: 9)
        try bindText(ClipboardContentType.image.rawValue, to: statement, index: 10)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    private func insertCaptureEvent(historyID: Int64, sourceApp: String?, sourceBundleID: String?) throws {
        let statement = try database.prepare(
            """
            INSERT INTO clipboard_capture_events (history_id, source_app, source_bundle_id)
            VALUES (?, ?, ?);
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindInt64(historyID, to: statement, index: 1)
        try bindNullableText(sourceApp, to: statement, index: 2)
        try bindNullableText(sourceBundleID, to: statement, index: 3)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    private func captureEventAggregates(before cutoff: Date) throws -> [CaptureEventAggregateKey: CaptureEventAggregate] {
        let statement = try database.prepare(
            """
            SELECT history_id, source_app, source_bundle_id, captured_at
            FROM clipboard_capture_events
            WHERE datetime(captured_at) < datetime(?);
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindText(dateFormatter.string(from: cutoff), to: statement, index: 1)
        var aggregates: [CaptureEventAggregateKey: CaptureEventAggregate] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let capturedAtValue = stringValue(statement, index: 3)
            guard let capturedAt = dateFormatter.date(from: capturedAtValue) else {
                throw DatabaseError.invalidDate(capturedAtValue)
            }
            let identity = CaptureSourceIdentity(
                appName: nullableStringValue(statement, index: 1),
                bundleID: nullableStringValue(statement, index: 2)
            )
            let key = CaptureEventAggregateKey(historyID: sqlite3_column_int64(statement, 0), sourceKey: identity.key)
            if var aggregate = aggregates[key] {
                aggregate.captureCount += 1
                aggregate.firstCapturedAt = min(aggregate.firstCapturedAt, capturedAt)
                aggregate.lastCapturedAt = max(aggregate.lastCapturedAt, capturedAt)
                aggregates[key] = aggregate
            } else {
                aggregates[key] = CaptureEventAggregate(
                    historyID: key.historyID,
                    identity: identity,
                    captureCount: 1,
                    firstCapturedAt: capturedAt,
                    lastCapturedAt: capturedAt
                )
            }
        }
        return aggregates
    }

    private func upsertCaptureEventSummary(_ aggregate: CaptureEventAggregate) throws {
        let statement = try database.prepare(
            """
            INSERT INTO clipboard_capture_event_summaries (
                history_id, source_key, source_app, source_bundle_id,
                capture_count, first_captured_at, last_captured_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(history_id, source_key) DO UPDATE SET
                source_app = excluded.source_app,
                source_bundle_id = excluded.source_bundle_id,
                capture_count = clipboard_capture_event_summaries.capture_count + excluded.capture_count,
                first_captured_at = MIN(clipboard_capture_event_summaries.first_captured_at, excluded.first_captured_at),
                last_captured_at = MAX(clipboard_capture_event_summaries.last_captured_at, excluded.last_captured_at);
            """
        )
        defer { sqlite3_finalize(statement) }

        try bindInt64(aggregate.historyID, to: statement, index: 1)
        try bindText(aggregate.identity.key, to: statement, index: 2)
        try bindNullableText(aggregate.identity.appName, to: statement, index: 3)
        try bindNullableText(aggregate.identity.bundleID, to: statement, index: 4)
        try bindInt(aggregate.captureCount, to: statement, index: 5)
        try bindText(dateFormatter.string(from: aggregate.firstCapturedAt), to: statement, index: 6)
        try bindText(dateFormatter.string(from: aggregate.lastCapturedAt), to: statement, index: 7)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    private func deleteCaptureEvents(before cutoff: Date) throws {
        let statement = try database.prepare(
            "DELETE FROM clipboard_capture_events WHERE datetime(captured_at) < datetime(?);"
        )
        defer { sqlite3_finalize(statement) }

        try bindText(dateFormatter.string(from: cutoff), to: statement, index: 1)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    private func fetchItem(id: Int64) throws -> ClipboardHistoryItem? {
        let statement = try database.prepare("\(Self.selectHistorySQL) WHERE id = ? LIMIT 1;")
        defer {
            sqlite3_finalize(statement)
        }

        try bindInt64(id, to: statement, index: 1)
        return try nextItem(from: statement)
    }

    private func fetchItem(contentHash: String) throws -> ClipboardHistoryItem? {
        let statement = try database.prepare("\(Self.selectHistorySQL) WHERE content_hash = ? LIMIT 1;")
        defer {
            sqlite3_finalize(statement)
        }

        try bindText(contentHash, to: statement, index: 1)
        return try nextItem(from: statement)
    }

    private func collectItems(from statement: OpaquePointer?) throws -> [ClipboardHistoryItem] {
        var items: [ClipboardHistoryItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            items.append(try item(from: statement))
        }
        return items
    }

    private func nextItem(from statement: OpaquePointer?) throws -> ClipboardHistoryItem? {
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        return try item(from: statement)
    }

    private func item(from statement: OpaquePointer?) throws -> ClipboardHistoryItem {
        let contentTypeValue = stringValue(statement, index: HistoryColumn.contentType.rawValue)
        let contentType = ClipboardContentType(rawValue: contentTypeValue) ?? .text
        let createdAtValue = stringValue(statement, index: HistoryColumn.createdAt.rawValue)
        let updatedAtValue = stringValue(statement, index: HistoryColumn.updatedAt.rawValue)

        guard let createdAt = dateFormatter.date(from: createdAtValue) else {
            throw DatabaseError.invalidDate(createdAtValue)
        }
        guard let updatedAt = dateFormatter.date(from: updatedAtValue) else {
            throw DatabaseError.invalidDate(updatedAtValue)
        }

        return ClipboardHistoryItem(
            id: sqlite3_column_int64(statement, HistoryColumn.id.rawValue),
            contentType: contentType,
            textContent: nullableStringValue(statement, index: HistoryColumn.textContent.rawValue) ?? "",
            filePath: nullableStringValue(statement, index: HistoryColumn.filePath.rawValue),
            thumbnailPath: nullableStringValue(statement, index: HistoryColumn.thumbnailPath.rawValue),
            sourceApp: nullableStringValue(statement, index: HistoryColumn.sourceApp.rawValue),
            sourceBundleID: nullableStringValue(statement, index: HistoryColumn.sourceBundleID.rawValue),
            contentHash: stringValue(statement, index: HistoryColumn.contentHash.rawValue),
            textLength: Int(sqlite3_column_int(statement, HistoryColumn.textLength.rawValue)),
            fileSize: nullableIntValue(statement, index: HistoryColumn.fileSize.rawValue),
            imageWidth: nullableIntValue(statement, index: HistoryColumn.imageWidth.rawValue),
            imageHeight: nullableIntValue(statement, index: HistoryColumn.imageHeight.rawValue),
            imageFormat: imageFormat(from: nullableStringValue(statement, index: HistoryColumn.imageFormat.rawValue)),
            isFavorite: sqlite3_column_int(statement, HistoryColumn.isFavorite.rawValue) == 1,
            isSensitive: sqlite3_column_int(statement, HistoryColumn.isSensitive.rawValue) == 1,
            createdAt: createdAt,
            updatedAt: updatedAt,
            searchableText: nullableStringValue(statement, index: HistoryColumn.searchableText.rawValue),
            detectedType: detectedType(from: nullableStringValue(statement, index: HistoryColumn.detectedType.rawValue)),
            userOverrideType: detectedType(from: nullableStringValue(statement, index: HistoryColumn.userOverrideType.rawValue)),
            detectionConfidence: nullableDoubleValue(statement, index: HistoryColumn.detectionConfidence.rawValue),
            detectionVersion: nullableIntValue(statement, index: HistoryColumn.detectionVersion.rawValue),
            detectedAt: try nullableDateValue(statement, index: HistoryColumn.detectedAt.rawValue),
            firstCapturedAt: try nullableDateValue(statement, index: HistoryColumn.firstCapturedAt.rawValue),
            lastCapturedAt: try nullableDateValue(statement, index: HistoryColumn.lastCapturedAt.rawValue),
            captureCount: nullableIntValue(statement, index: HistoryColumn.captureCount.rawValue) ?? 1,
            reuseCopyCount: nullableIntValue(statement, index: HistoryColumn.reuseCopyCount.rawValue) ?? 0,
            pasteCount: nullableIntValue(statement, index: HistoryColumn.pasteCount.rawValue) ?? 0,
            lastReuseCopiedAt: try nullableDateValue(statement, index: HistoryColumn.lastReuseCopiedAt.rawValue),
            lastPastedAt: try nullableDateValue(statement, index: HistoryColumn.lastPastedAt.rawValue),
            ocrStatus: ocrStatus(from: nullableStringValue(statement, index: HistoryColumn.ocrStatus.rawValue)),
            ocrText: nullableStringValue(statement, index: HistoryColumn.ocrText.rawValue),
            ocrUpdatedAt: try nullableDateValue(statement, index: HistoryColumn.ocrUpdatedAt.rawValue),
            ocrErrorCode: nullableStringValue(statement, index: HistoryColumn.ocrErrorCode.rawValue),
            derivedFromHistoryID: nullableInt64Value(statement, index: HistoryColumn.derivedFromHistoryID.rawValue),
            derivedActionID: nullableStringValue(statement, index: HistoryColumn.derivedActionID.rawValue),
            derivedActionSummary: nullableStringValue(statement, index: HistoryColumn.derivedActionSummary.rawValue),
            derivedAt: try nullableDateValue(statement, index: HistoryColumn.derivedAt.rawValue),
            derivedSourcePreview: nullableStringValue(statement, index: HistoryColumn.derivedSourcePreview.rawValue),
            derivedSourceHash: nullableStringValue(statement, index: HistoryColumn.derivedSourceHash.rawValue)
        )
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, index: Int32) throws {
        guard sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    private func bindNullableText(_ value: String?, to statement: OpaquePointer?, index: Int32) throws {
        guard let value else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw DatabaseError.bindFailed(database.lastErrorMessage)
            }
            return
        }
        try bindText(value, to: statement, index: index)
    }

    private func bindInt(_ value: Int, to statement: OpaquePointer?, index: Int32) throws {
        guard sqlite3_bind_int(statement, index, Int32(value)) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    private func bindInt64(_ value: Int64, to statement: OpaquePointer?, index: Int32) throws {
        guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    private func bindDouble(_ value: Double, to statement: OpaquePointer?, index: Int32) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    private func stepUpdate(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    private func stringValue(_ statement: OpaquePointer?, index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: text)
    }

    private func nullableStringValue(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return stringValue(statement, index: index)
    }

    private func nullableIntValue(_ statement: OpaquePointer?, index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Int(sqlite3_column_int(statement, index))
    }

    private func nullableInt64Value(_ statement: OpaquePointer?, index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_int64(statement, index)
    }

    private func nullableDoubleValue(_ statement: OpaquePointer?, index: Int32) -> Double? {
        let columnType = sqlite3_column_type(statement, index)
        guard columnType == SQLITE_FLOAT || columnType == SQLITE_INTEGER else {
            return nil
        }
        let value = sqlite3_column_double(statement, index)
        guard value.isFinite, (0...1).contains(value) else {
            return nil
        }
        return value
    }

    private func nullableDateValue(_ statement: OpaquePointer?, index: Int32) throws -> Date? {
        guard let value = nullableStringValue(statement, index: index) else {
            return nil
        }
        return dateFormatter.date(from: value)
    }

    private func detectedType(from value: String?) -> DetectedContentType? {
        value.flatMap(DetectedContentType.init(rawValue:))
    }

    private func ocrStatus(from value: String?) -> OCRStatus {
        value.flatMap(OCRStatus.init(rawValue:)) ?? .notStarted
    }

    private func imageFormat(from value: String?) -> ClipboardImageFormat? {
        guard let value else {
            return nil
        }
        return ClipboardImageFormat(rawValue: value)
    }

    private static let selectHistorySQL = """
    SELECT
        id,
        content_type,
        text_content,
        file_path,
        thumbnail_path,
        source_app,
        source_bundle_id,
        content_hash,
        text_length,
        file_size,
        image_width,
        image_height,
        image_format,
        is_favorite,
        is_sensitive,
        created_at,
        updated_at,
        searchable_text,
        detected_type,
        user_override_type,
        detection_confidence,
        detection_version,
        detected_at,
        first_captured_at,
        last_captured_at,
        capture_count,
        reuse_copy_count,
        paste_count,
        last_reuse_copied_at,
        last_pasted_at,
        ocr_status,
        ocr_text,
        ocr_updated_at,
        ocr_error_code,
        derived_from_history_id,
        derived_action_id,
        derived_action_summary,
        derived_at,
        derived_source_preview,
        derived_source_hash
    FROM clipboard_history
    """

    private enum HistoryColumn: Int32 {
        case id
        case contentType
        case textContent
        case filePath
        case thumbnailPath
        case sourceApp
        case sourceBundleID
        case contentHash
        case textLength
        case fileSize
        case imageWidth
        case imageHeight
        case imageFormat
        case isFavorite
        case isSensitive
        case createdAt
        case updatedAt
        case searchableText
        case detectedType
        case userOverrideType
        case detectionConfidence
        case detectionVersion
        case detectedAt
        case firstCapturedAt
        case lastCapturedAt
        case captureCount
        case reuseCopyCount
        case pasteCount
        case lastReuseCopiedAt
        case lastPastedAt
        case ocrStatus
        case ocrText
        case ocrUpdatedAt
        case ocrErrorCode
        case derivedFromHistoryID
        case derivedActionID
        case derivedActionSummary
        case derivedAt
        case derivedSourcePreview
        case derivedSourceHash
    }

    private struct CaptureEventAggregateKey: Hashable {
        let historyID: Int64
        let sourceKey: String
    }

    private struct CaptureEventAggregate {
        let historyID: Int64
        let identity: CaptureSourceIdentity
        var captureCount: Int
        var firstCapturedAt: Date
        var lastCapturedAt: Date
    }
}

private extension DateFormatter {
    static var sqliteDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
