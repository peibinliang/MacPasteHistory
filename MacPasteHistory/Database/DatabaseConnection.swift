import Foundation
import SQLite3

final class DatabaseConnection {
    let databaseURL: URL
    private(set) var handle: OpaquePointer?

    init(databaseURL: URL, mode: DatabaseOpenMode = .readWriteCreate) throws {
        self.databaseURL = databaseURL

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, mode.flags, nil) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            if let database {
                sqlite3_close(database)
            }
            throw DatabaseError.openFailed(message)
        }
        handle = database

        do {
            guard sqlite3_busy_timeout(database, 1_000) == SQLITE_OK else {
                throw DatabaseError.executeFailed(lastErrorMessage)
            }
            try execute("PRAGMA foreign_keys = ON;")
        } catch {
            sqlite3_close(database)
            handle = nil
            throw error
        }
    }

    deinit {
        try? close()
    }

    func close() throws {
        guard let handle else {
            return
        }
        guard sqlite3_close(handle) == SQLITE_OK else {
            throw DatabaseError.executeFailed(lastErrorMessage)
        }
        self.handle = nil
    }

    func execute(_ sql: String) throws {
        guard let handle else {
            throw DatabaseError.executeFailed("Database is closed")
        }

        var errorMessage: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(handle, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage
            sqlite3_free(errorMessage)
            throw DatabaseError.executeFailed(message)
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer? {
        guard let handle else {
            throw DatabaseError.prepareFailed("Database is closed")
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(lastErrorMessage)
        }
        return statement
    }

    func inTransaction<T>(_ operation: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let value = try operation()
            try execute("COMMIT;")
            return value
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func foreignKeysAreEnabled() throws -> Bool {
        let statement = try prepare("PRAGMA foreign_keys;")
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(lastErrorMessage)
        }
        return sqlite3_column_int(statement, 0) == 1
    }

    var lastInsertedRowID: Int64 {
        guard let handle else {
            return 0
        }
        return sqlite3_last_insert_rowid(handle)
    }

    var lastErrorMessage: String {
        guard let handle else {
            return "Database is closed"
        }
        return String(cString: sqlite3_errmsg(handle))
    }
}
