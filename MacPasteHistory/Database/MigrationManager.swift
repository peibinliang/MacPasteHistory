import Foundation
import SQLite3

final class MigrationManager {
    private let database: DatabaseConnection

    init(database: DatabaseConnection) {
        self.database = database
    }

    func migrate() throws {
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            """
        )
        try applyMigration(version: 1, name: "create_clipboard_history", sql: Self.createClipboardHistorySQL)
        try applyMigration(version: 2, name: "add_image_format_to_clipboard_history", sql: Self.addImageFormatSQL)
        try applyMigration(version: 3, name: "enhanced_search_content_actions", sql: Self.enhancedHistorySQL)
        try applyMigration(version: 4, name: "create_ai_token_usage", sql: Self.createAITokenUsageSQL)
    }

    private func applyMigration(version: Int, name: String, sql: String) throws {
        if try hasAppliedMigration(version: version) {
            return
        }

        try database.inTransaction {
            try database.execute(sql)
            try recordMigration(version: version, name: name)
        }
    }

    private func recordMigration(version: Int, name: String) throws {
        let statement = try database.prepare(
            "INSERT INTO schema_migrations (version, name) VALUES (?, ?);"
        )
        defer { sqlite3_finalize(statement) }

        guard sqlite3_bind_int(statement, 1, Int32(version)) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
        guard sqlite3_bind_text(statement, 2, name, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    private func hasAppliedMigration(version: Int) throws -> Bool {
        let statement = try database.prepare("SELECT 1 FROM schema_migrations WHERE version = ? LIMIT 1;")
        defer {
            sqlite3_finalize(statement)
        }
        guard sqlite3_bind_int(statement, 1, Int32(version)) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private static let createClipboardHistorySQL = """
    CREATE TABLE IF NOT EXISTS clipboard_history (
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
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE UNIQUE INDEX IF NOT EXISTS idx_clipboard_hash
    ON clipboard_history(content_hash);

    CREATE INDEX IF NOT EXISTS idx_clipboard_created_at
    ON clipboard_history(created_at);

    CREATE INDEX IF NOT EXISTS idx_clipboard_content_type
    ON clipboard_history(content_type);

    CREATE INDEX IF NOT EXISTS idx_clipboard_favorite
    ON clipboard_history(is_favorite);

    CREATE INDEX IF NOT EXISTS idx_clipboard_text_content
    ON clipboard_history(text_content);
    """

    private static let addImageFormatSQL = """
    ALTER TABLE clipboard_history
    ADD COLUMN image_format TEXT;
    """

    private static let enhancedHistorySQL = """
    ALTER TABLE clipboard_history ADD COLUMN searchable_text TEXT;
    ALTER TABLE clipboard_history ADD COLUMN detected_type TEXT;
    ALTER TABLE clipboard_history ADD COLUMN user_override_type TEXT;
    ALTER TABLE clipboard_history ADD COLUMN detection_confidence REAL;
    ALTER TABLE clipboard_history ADD COLUMN detection_version INTEGER;
    ALTER TABLE clipboard_history ADD COLUMN detected_at DATETIME;
    ALTER TABLE clipboard_history ADD COLUMN first_captured_at DATETIME;
    ALTER TABLE clipboard_history ADD COLUMN last_captured_at DATETIME;
    ALTER TABLE clipboard_history ADD COLUMN capture_count INTEGER NOT NULL DEFAULT 1;
    ALTER TABLE clipboard_history ADD COLUMN reuse_copy_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE clipboard_history ADD COLUMN paste_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE clipboard_history ADD COLUMN last_reuse_copied_at DATETIME;
    ALTER TABLE clipboard_history ADD COLUMN last_pasted_at DATETIME;
    ALTER TABLE clipboard_history ADD COLUMN ocr_status TEXT NOT NULL DEFAULT 'notStarted';
    ALTER TABLE clipboard_history ADD COLUMN ocr_text TEXT;
    ALTER TABLE clipboard_history ADD COLUMN ocr_updated_at DATETIME;
    ALTER TABLE clipboard_history ADD COLUMN ocr_error_code TEXT;
    ALTER TABLE clipboard_history ADD COLUMN derived_from_history_id INTEGER
        REFERENCES clipboard_history(id) ON DELETE SET NULL;
    ALTER TABLE clipboard_history ADD COLUMN derived_action_id TEXT;
    ALTER TABLE clipboard_history ADD COLUMN derived_action_summary TEXT;
    ALTER TABLE clipboard_history ADD COLUMN derived_at DATETIME;
    ALTER TABLE clipboard_history ADD COLUMN derived_source_preview TEXT;
    ALTER TABLE clipboard_history ADD COLUMN derived_source_hash TEXT;

    UPDATE clipboard_history
    SET searchable_text = COALESCE(text_content, ''),
        first_captured_at = created_at,
        last_captured_at = created_at
    WHERE first_captured_at IS NULL
       OR last_captured_at IS NULL
       OR searchable_text IS NULL;

    CREATE TABLE clipboard_capture_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        history_id INTEGER NOT NULL,
        source_app TEXT,
        source_bundle_id TEXT,
        captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(history_id) REFERENCES clipboard_history(id) ON DELETE CASCADE
    );

    CREATE TABLE clipboard_capture_event_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        history_id INTEGER NOT NULL,
        source_key TEXT NOT NULL,
        source_app TEXT,
        source_bundle_id TEXT,
        capture_count INTEGER NOT NULL DEFAULT 0,
        first_captured_at DATETIME NOT NULL,
        last_captured_at DATETIME NOT NULL,
        UNIQUE(history_id, source_key),
        FOREIGN KEY(history_id) REFERENCES clipboard_history(id) ON DELETE CASCADE
    );

    CREATE INDEX idx_clipboard_last_captured_at
    ON clipboard_history(last_captured_at DESC);

    CREATE INDEX idx_clipboard_detected_type
    ON clipboard_history(detected_type);

    CREATE INDEX idx_clipboard_user_override_type
    ON clipboard_history(user_override_type);

    CREATE INDEX idx_clipboard_last_pasted_at
    ON clipboard_history(last_pasted_at DESC);

    CREATE INDEX idx_capture_events_history_time
    ON clipboard_capture_events(history_id, captured_at DESC);

    CREATE INDEX idx_capture_events_captured_at
    ON clipboard_capture_events(captured_at);
    """

    private static let createAITokenUsageSQL = """
    CREATE TABLE ai_token_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id TEXT NOT NULL UNIQUE,
        provider TEXT NOT NULL,
        model_identifier TEXT NOT NULL,
        input_tokens INTEGER NOT NULL CHECK (input_tokens >= 0),
        output_tokens INTEGER NOT NULL CHECK (output_tokens >= 0),
        total_tokens INTEGER NOT NULL CHECK (total_tokens >= 0),
        cached_input_tokens INTEGER CHECK (cached_input_tokens IS NULL OR cached_input_tokens >= 0),
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX idx_ai_token_usage_model_created_at
    ON ai_token_usage(model_identifier, created_at DESC);

    CREATE INDEX idx_ai_token_usage_created_at
    ON ai_token_usage(created_at DESC);
    """
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
