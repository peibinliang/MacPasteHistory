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
    }

    private func applyMigration(version: Int, name: String, sql: String) throws {
        if try hasAppliedMigration(version: version) {
            return
        }
        try database.execute("BEGIN TRANSACTION;")
        do {
            try database.execute(sql)
            try database.execute(
                """
                INSERT INTO schema_migrations (version, name)
                VALUES (\(version), '\(name)');
                """
            )
            try database.execute("COMMIT;")
        } catch {
            try? database.execute("ROLLBACK;")
            throw error
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
}
