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

        if let existingItem = try fetchItem(contentHash: contentHash) {
            try updateDuplicateTextItem(id: existingItem.id, sourceApp: sourceApp, sourceBundleID: sourceBundleID)
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
                text_length
            )
            VALUES (?, ?, ?, ?, ?, ?);
            """
        )
        defer {
            sqlite3_finalize(statement)
        }

        try bindText(ClipboardContentType.text.rawValue, to: statement, index: 1)
        try bindText(normalizedText, to: statement, index: 2)
        try bindNullableText(sourceApp, to: statement, index: 3)
        try bindNullableText(sourceBundleID, to: statement, index: 4)
        try bindText(contentHash, to: statement, index: 5)
        try bindInt(normalizedText.count, to: statement, index: 6)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }

        guard let item = try fetchItem(id: database.lastInsertedRowID) else {
            throw DatabaseError.stepFailed("Inserted text history item could not be loaded")
        }
        return item
    }

    func fetchTextHistory(matching keyword: String?) throws -> [ClipboardHistoryItem] {
        try fetchHistory(query: HistoryQuery(keyword: keyword, contentType: .text))
    }

    func saveImage(
        _ image: StoredClipboardImage,
        sourceApp: String?,
        sourceBundleID: String?
    ) throws -> ClipboardHistoryItem {
        if let existingItem = try fetchItem(contentHash: image.contentHash) {
            try updateDuplicateImageItem(
                id: existingItem.id,
                image: image,
                sourceApp: sourceApp,
                sourceBundleID: sourceBundleID
            )
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
                image_format
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )
        defer {
            sqlite3_finalize(statement)
        }

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

        guard let item = try fetchItem(id: database.lastInsertedRowID) else {
            throw DatabaseError.stepFailed("Inserted image history item could not be loaded")
        }
        return item
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
        try bindInt(query.limit, to: statement, index: bindIndex)
        try bindInt(query.offset, to: statement, index: bindIndex + 1)

        return try collectItems(from: statement)
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
                created_at = CURRENT_TIMESTAMP,
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
                created_at = CURRENT_TIMESTAMP,
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
        let contentTypeValue = stringValue(statement, index: 1)
        let contentType = ClipboardContentType(rawValue: contentTypeValue) ?? .text
        let createdAtValue = stringValue(statement, index: 15)
        let updatedAtValue = stringValue(statement, index: 16)

        guard let createdAt = dateFormatter.date(from: createdAtValue) else {
            throw DatabaseError.invalidDate(createdAtValue)
        }
        guard let updatedAt = dateFormatter.date(from: updatedAtValue) else {
            throw DatabaseError.invalidDate(updatedAtValue)
        }

        return ClipboardHistoryItem(
            id: sqlite3_column_int64(statement, 0),
            contentType: contentType,
            textContent: nullableStringValue(statement, index: 2) ?? "",
            filePath: nullableStringValue(statement, index: 3),
            thumbnailPath: nullableStringValue(statement, index: 4),
            sourceApp: nullableStringValue(statement, index: 5),
            sourceBundleID: nullableStringValue(statement, index: 6),
            contentHash: stringValue(statement, index: 7),
            textLength: Int(sqlite3_column_int(statement, 8)),
            fileSize: nullableIntValue(statement, index: 9),
            imageWidth: nullableIntValue(statement, index: 10),
            imageHeight: nullableIntValue(statement, index: 11),
            imageFormat: imageFormat(from: nullableStringValue(statement, index: 12)),
            isFavorite: sqlite3_column_int(statement, 13) == 1,
            isSensitive: sqlite3_column_int(statement, 14) == 1,
            createdAt: createdAt,
            updatedAt: updatedAt
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
        updated_at
    FROM clipboard_history
    """
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
