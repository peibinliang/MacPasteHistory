import XCTest
@testable import MacPasteHistory

final class DataCleanupServiceTests: XCTestCase {
    private var rootURL: URL!
    private var databaseURL: URL!
    private var imagesURL: URL!
    private var thumbnailsURL: URL!
    private var database: DatabaseConnection!
    private var repository: ClipboardHistoryRepository!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        databaseURL = rootURL.appendingPathComponent("clipboard.sqlite")
        imagesURL = rootURL.appendingPathComponent("images", isDirectory: true)
        thumbnailsURL = rootURL.appendingPathComponent("thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)

        database = try DatabaseConnection(databaseURL: databaseURL)
        try MigrationManager(database: database).migrate()
        repository = ClipboardHistoryRepository(database: database)

        defaultsSuiteName = "DataCleanupServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDownWithError() throws {
        repository = nil
        try database?.close()
        database = nil
        if let defaults {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        defaults = nil
        defaultsSuiteName = nil
        if let rootURL {
            try? FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        databaseURL = nil
        imagesURL = nil
        thumbnailsURL = nil
        try super.tearDownWithError()
    }

    func testPerformStartupCleanup_whenImageRecordIsExpired_shouldDeleteDatabaseRecordAndFiles() throws {
        let originalURL = imagesURL.appendingPathComponent("expired.png")
        let thumbnailURL = thumbnailsURL.appendingPathComponent("expired.png")
        try Data("expired original".utf8).write(to: originalURL)
        try Data("expired thumbnail".utf8).write(to: thumbnailURL)
        let storedImage = StoredClipboardImage(
            fileURL: originalURL,
            thumbnailURL: thumbnailURL,
            contentHash: "expired-image-hash",
            fileSize: 16,
            width: 16,
            height: 16,
            format: .png
        )
        let item = try repository.saveImage(storedImage, sourceApp: nil, sourceBundleID: nil)
        try database.execute(
            """
            UPDATE clipboard_history
            SET created_at = datetime('now', '-31 days'),
                updated_at = datetime('now', '-31 days')
            WHERE id = \(item.id);
            """
        )
        let cleanup = DataCleanupService(
            repository: repository,
            imageStorageService: ImageStorageService(imagesDirectory: imagesURL, thumbnailsDirectory: thumbnailsURL),
            settings: UserDefaultsConfig(defaults: defaults)
        )

        cleanup.performStartupCleanup()

        XCTAssertTrue(try repository.fetchHistory(query: HistoryQuery(contentType: .image)).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbnailURL.path))
    }
}
