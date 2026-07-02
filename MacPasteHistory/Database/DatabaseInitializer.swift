import Foundation
import SQLite3

final class DatabaseInitializer {
    private let applicationSupportService: ApplicationSupportService
    private let logger: Logger

    init(applicationSupportService: ApplicationSupportService, logger: Logger) {
        self.applicationSupportService = applicationSupportService
        self.logger = logger
    }

    func initializeDatabase() throws {
        var database: OpaquePointer?
        let databasePath = try applicationSupportService.databaseURL.path

        guard sqlite3_open(databasePath, &database) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            throw DatabaseInitializationError.openFailed(message)
        }

        defer {
            sqlite3_close(database)
        }

        logger.info("SQLite database opened")
    }
}
