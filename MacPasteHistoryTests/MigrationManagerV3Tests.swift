import SQLite3
import XCTest

@testable import MacPasteHistory

final class MigrationManagerV3Tests: XCTestCase {
    func testMigrate_whenDatabaseIsVersion2_shouldApplyVersion3SchemaAndBackfill() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try createVersion2Database(on: temporary.connection, includeLegacyRecord: true)

        try MigrationManager(database: temporary.connection).migrate()

        XCTAssertEqual(try migrationVersions(in: temporary.connection), [1, 2, 3])
        XCTAssertTrue(try tableExists("clipboard_capture_events", in: temporary.connection))
        XCTAssertTrue(try tableExists("clipboard_capture_event_summaries", in: temporary.connection))
        XCTAssertTrue(requiredHistoryColumns.isSubset(of: try columnNames(
            in: "clipboard_history",
            database: temporary.connection
        )))
        XCTAssertTrue(requiredEventColumns.isSubset(of: try columnNames(
            in: "clipboard_capture_events",
            database: temporary.connection
        )))
        XCTAssertTrue(requiredSummaryColumns.isSubset(of: try columnNames(
            in: "clipboard_capture_event_summaries",
            database: temporary.connection
        )))
        XCTAssertTrue(requiredIndexes.isSubset(of: try indexNames(in: temporary.connection)))

        let values = try legacyBackfillValues(in: temporary.connection)
        XCTAssertEqual(values.searchableText, "legacy text")
        XCTAssertEqual(values.firstCapturedAt, "2026-07-01 10:11:12")
        XCTAssertEqual(values.lastCapturedAt, "2026-07-01 10:11:12")
        XCTAssertEqual(values.captureCount, 1)
        XCTAssertEqual(values.reuseCopyCount, 0)
        XCTAssertEqual(values.pasteCount, 0)
        XCTAssertEqual(values.ocrStatus, "notStarted")
    }

    func testMigrate_whenRunTwice_shouldRemainIdempotent() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try createVersion2Database(on: temporary.connection)
        let migrator = MigrationManager(database: temporary.connection)

        try migrator.migrate()
        try migrator.migrate()

        XCTAssertEqual(try migrationVersions(in: temporary.connection), [1, 2, 3])
        XCTAssertEqual(try versionRowCount(3, in: temporary.connection), 1)
    }

    func testMigrate_shouldCreateRequiredForeignKeyDeleteActions() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try createVersion2Database(on: temporary.connection)

        try MigrationManager(database: temporary.connection).migrate()

        XCTAssertEqual(
            try foreignKeyDeleteAction(
                table: "clipboard_history",
                fromColumn: "derived_from_history_id",
                database: temporary.connection
            ),
            "SET NULL"
        )
        XCTAssertEqual(
            try foreignKeyDeleteAction(
                table: "clipboard_capture_events",
                fromColumn: "history_id",
                database: temporary.connection
            ),
            "CASCADE"
        )
        XCTAssertEqual(
            try foreignKeyDeleteAction(
                table: "clipboard_capture_event_summaries",
                fromColumn: "history_id",
                database: temporary.connection
            ),
            "CASCADE"
        )
    }

    func testMigrate_whenVersion3Fails_shouldRollbackSchemaChangesAndVersionRow() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try createVersion2Database(on: temporary.connection)
        try temporary.connection.execute(
            "CREATE VIEW clipboard_capture_events AS SELECT 1 AS incompatible_schema;"
        )

        XCTAssertThrowsError(try MigrationManager(database: temporary.connection).migrate())

        XCTAssertFalse(try columnNames(
            in: "clipboard_history",
            database: temporary.connection
        ).contains("searchable_text"))
        XCTAssertEqual(try versionRowCount(3, in: temporary.connection), 0)
    }

    private func createVersion2Database(
        on database: DatabaseConnection,
        includeLegacyRecord: Bool = false
    ) throws {
        try database.execute(
            """
            CREATE TABLE schema_migrations (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE clipboard_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content_type TEXT NOT NULL,
                text_content TEXT,
                file_path TEXT,
                thumbnail_path TEXT,
                source_app TEXT,
                source_bundle_id TEXT,
                content_hash TEXT NOT NULL,
                text_length INTEGER NOT NULL DEFAULT 0,
                file_size INTEGER,
                image_width INTEGER,
                image_height INTEGER,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                is_sensitive INTEGER NOT NULL DEFAULT 0,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                image_format TEXT
            );

            INSERT INTO schema_migrations (version, name) VALUES
                (1, 'create_clipboard_history'),
                (2, 'add_image_format_to_clipboard_history');
            """
        )

        guard includeLegacyRecord else {
            return
        }
        try database.execute(
            """
            INSERT INTO clipboard_history (
                content_type,
                text_content,
                content_hash,
                text_length,
                created_at,
                updated_at
            ) VALUES (
                'text',
                'legacy text',
                'legacy-hash',
                11,
                '2026-07-01 10:11:12',
                '2026-07-01 10:11:12'
            );
            """
        )
    }

    private func migrationVersions(in database: DatabaseConnection) throws -> [Int32] {
        let statement = try database.prepare("SELECT version FROM schema_migrations ORDER BY version;")
        defer { sqlite3_finalize(statement) }

        var versions: [Int32] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            versions.append(sqlite3_column_int(statement, 0))
        }
        return versions
    }

    private func versionRowCount(_ version: Int32, in database: DatabaseConnection) throws -> Int32 {
        let statement = try database.prepare(
            "SELECT COUNT(*) FROM schema_migrations WHERE version = \(version);"
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
        return sqlite3_column_int(statement, 0)
    }

    private func tableExists(_ name: String, in database: DatabaseConnection) throws -> Bool {
        let statement = try database.prepare(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = '\(name)' LIMIT 1;"
        )
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func columnNames(in table: String, database: DatabaseConnection) throws -> Set<String> {
        let statement = try database.prepare("PRAGMA table_info(\(table));")
        defer { sqlite3_finalize(statement) }

        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 1) {
                names.insert(String(cString: name))
            }
        }
        return names
    }

    private func indexNames(in database: DatabaseConnection) throws -> Set<String> {
        let statement = try database.prepare(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name IS NOT NULL;"
        )
        defer { sqlite3_finalize(statement) }

        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 0) {
                names.insert(String(cString: name))
            }
        }
        return names
    }

    private func foreignKeyDeleteAction(
        table: String,
        fromColumn: String,
        database: DatabaseConnection
    ) throws -> String? {
        let statement = try database.prepare("PRAGMA foreign_key_list(\(table));")
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let column = sqlite3_column_text(statement, 3),
                  String(cString: column) == fromColumn,
                  let action = sqlite3_column_text(statement, 6) else {
                continue
            }
            return String(cString: action)
        }
        return nil
    }

    private func legacyBackfillValues(in database: DatabaseConnection) throws -> LegacyBackfillValues {
        let statement = try database.prepare(
            """
            SELECT searchable_text, first_captured_at, last_captured_at,
                   capture_count, reuse_copy_count, paste_count, ocr_status
            FROM clipboard_history
            WHERE content_hash = 'legacy-hash';
            """
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }

        return LegacyBackfillValues(
            searchableText: stringValue(statement, index: 0),
            firstCapturedAt: stringValue(statement, index: 1),
            lastCapturedAt: stringValue(statement, index: 2),
            captureCount: sqlite3_column_int(statement, 3),
            reuseCopyCount: sqlite3_column_int(statement, 4),
            pasteCount: sqlite3_column_int(statement, 5),
            ocrStatus: stringValue(statement, index: 6)
        )
    }

    private func stringValue(_ statement: OpaquePointer?, index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: value)
    }

    private var requiredHistoryColumns: Set<String> {
        [
            "searchable_text", "detected_type", "user_override_type", "detection_confidence",
            "detection_version", "detected_at", "first_captured_at", "last_captured_at",
            "capture_count", "reuse_copy_count", "paste_count", "last_reuse_copied_at",
            "last_pasted_at", "ocr_status", "ocr_text", "ocr_updated_at", "ocr_error_code",
            "derived_from_history_id", "derived_action_id", "derived_action_summary", "derived_at",
            "derived_source_preview", "derived_source_hash"
        ]
    }

    private var requiredEventColumns: Set<String> {
        ["id", "history_id", "source_app", "source_bundle_id", "captured_at"]
    }

    private var requiredSummaryColumns: Set<String> {
        [
            "id", "history_id", "source_key", "source_app", "source_bundle_id", "capture_count",
            "first_captured_at", "last_captured_at"
        ]
    }

    private var requiredIndexes: Set<String> {
        [
            "idx_clipboard_last_captured_at", "idx_clipboard_detected_type",
            "idx_clipboard_user_override_type", "idx_clipboard_last_pasted_at",
            "idx_capture_events_history_time", "idx_capture_events_captured_at"
        ]
    }
}

private struct LegacyBackfillValues {
    let searchableText: String
    let firstCapturedAt: String
    let lastCapturedAt: String
    let captureCount: Int32
    let reuseCopyCount: Int32
    let pasteCount: Int32
    let ocrStatus: String
}
