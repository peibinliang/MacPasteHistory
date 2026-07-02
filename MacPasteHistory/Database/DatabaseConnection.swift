import Foundation
import SQLite3

final class DatabaseConnection {
    private(set) var handle: OpaquePointer?

    init(databaseURL: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            if let database {
                sqlite3_close(database)
            }
            throw DatabaseError.openFailed(message)
        }
        handle = database
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
