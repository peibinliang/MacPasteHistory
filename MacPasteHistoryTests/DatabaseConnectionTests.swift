import SQLite3
import XCTest

@testable import MacPasteHistory

final class DatabaseConnectionTests: XCTestCase {
    func testInit_shouldEnableForeignKeys() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }

        XCTAssertTrue(try temporary.connection.foreignKeysAreEnabled())
    }

    func testReadOnlyConnection_shouldReadExistingDatabase() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()

        let readOnly = try DatabaseConnection(databaseURL: temporary.url, mode: .readOnly)
        defer { try? readOnly.close() }

        let statement = try readOnly.prepare("SELECT COUNT(*) FROM schema_migrations;")
        defer { sqlite3_finalize(statement) }

        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
    }

    func testInTransaction_whenOperationThrows_shouldRollbackChanges() throws {
        enum ExpectedFailure: Error {
            case operationFailed
        }

        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try temporary.connection.execute("CREATE TABLE transaction_test (value TEXT NOT NULL);")

        XCTAssertThrowsError(
            try temporary.connection.inTransaction {
                try temporary.connection.execute("INSERT INTO transaction_test (value) VALUES ('rollback');")
                throw ExpectedFailure.operationFailed
            }
        ) { error in
            XCTAssertTrue(error is ExpectedFailure)
        }

        XCTAssertEqual(try rowCount(in: temporary.connection, table: "transaction_test"), 0)
    }

    func testInTransaction_whenOperationSucceeds_shouldCommitChanges() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try temporary.connection.execute("CREATE TABLE transaction_test (value TEXT NOT NULL);")

        let result = try temporary.connection.inTransaction {
            try temporary.connection.execute("INSERT INTO transaction_test (value) VALUES ('commit');")
            return "completed"
        }

        XCTAssertEqual(result, "completed")
        XCTAssertEqual(try rowCount(in: temporary.connection, table: "transaction_test"), 1)
    }

    private func rowCount(in database: DatabaseConnection, table: String) throws -> Int32 {
        let statement = try database.prepare("SELECT COUNT(*) FROM \(table);")
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
        return sqlite3_column_int(statement, 0)
    }
}
