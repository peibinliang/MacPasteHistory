import Foundation
import SQLite3

final class DatabaseInitializer {
    private let applicationSupportService: ApplicationSupportService
    private let logger: Logger
    private var database: DatabaseConnection?

    init(applicationSupportService: ApplicationSupportService, logger: Logger) {
        self.applicationSupportService = applicationSupportService
        self.logger = logger
    }

    func initializeDatabase() throws {
        let connection = try DatabaseConnection(databaseURL: applicationSupportService.databaseURL)
        try MigrationManager(database: connection).migrate()
        database = connection
        logger.info("SQLite database opened")
    }

    func currentDatabase() -> DatabaseConnection? {
        database
    }
}
