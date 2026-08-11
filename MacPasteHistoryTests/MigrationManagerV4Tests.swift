import SQLite3
import XCTest
@testable import MacPasteHistory

final class MigrationManagerV4Tests: XCTestCase {
    func testMigrate_whenVersion3DatabaseExists_shouldCreateUsageSchema() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        let migrator = MigrationManager(database: temporary.connection)
        try migrator.migrate()
        try temporary.connection.execute("DROP TABLE ai_token_usage;")
        try temporary.connection.execute("DELETE FROM schema_migrations WHERE version = 4;")

        try migrator.migrate()

        XCTAssertTrue(try tableExists("ai_token_usage", database: temporary.connection))
        XCTAssertTrue(try indexExists("idx_ai_token_usage_model_created_at", database: temporary.connection))
        XCTAssertEqual(try versionRowCount(4, database: temporary.connection), 1)
    }

    func testMigrate_whenDatabaseIsNew_shouldCreateUsageSchema() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }

        try MigrationManager(database: temporary.connection).migrate()

        XCTAssertTrue(try tableExists("ai_token_usage", database: temporary.connection))
    }

    private func tableExists(_ name: String, database: DatabaseConnection) throws -> Bool {
        let statement = try database.prepare(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1;"
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_bind_text(statement, 1, name, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func indexExists(_ name: String, database: DatabaseConnection) throws -> Bool {
        let statement = try database.prepare(
            "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ? LIMIT 1;"
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_bind_text(statement, 1, name, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DatabaseError.bindFailed(database.lastErrorMessage)
        }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func versionRowCount(_ version: Int32, database: DatabaseConnection) throws -> Int32 {
        let statement = try database.prepare("SELECT COUNT(*) FROM schema_migrations WHERE version = ?;")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_bind_int(statement, 1, version) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
        return sqlite3_column_int(statement, 0)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
