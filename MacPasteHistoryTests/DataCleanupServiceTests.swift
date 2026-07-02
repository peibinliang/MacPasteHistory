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

    func testPerformStartupCleanup_whenTextCountExceedsLimit_shouldDeleteOldestNonFavoriteText() throws {
        var settings = UserDefaultsConfig(defaults: defaults)
        settings.maxTextHistoryCount = 2
        let oldest = try repository.saveText("oldest text", sourceApp: nil, sourceBundleID: nil)
        let favorite = try repository.saveText("favorite text", sourceApp: nil, sourceBundleID: nil)
        let newest = try repository.saveText("newest text", sourceApp: nil, sourceBundleID: nil)
        try repository.setFavorite(true, id: favorite.id)
        try setCreatedAt(id: oldest.id, daysAgo: 3)
        try setCreatedAt(id: favorite.id, daysAgo: 2)
        try setCreatedAt(id: newest.id, daysAgo: 1)
        let cleanup = makeCleanup(settings: settings)

        cleanup.performStartupCleanup()

        let remainingText = try repository.fetchHistory(query: HistoryQuery(contentType: .text)).map(\.textContent)
        XCTAssertEqual(Set(remainingText), ["favorite text", "newest text"])
    }

    func testPerformStartupCleanup_whenImageCountExceedsLimit_shouldDeleteOldestImageAndFiles() throws {
        var settings = UserDefaultsConfig(defaults: defaults)
        settings.maxImageHistoryCount = 1
        let oldImage = try saveImage(name: "old-count", fileSize: 100)
        let newImage = try saveImage(name: "new-count", fileSize: 100)
        try setCreatedAt(id: oldImage.id, daysAgo: 2)
        try setCreatedAt(id: newImage.id, daysAgo: 1)
        let cleanup = makeCleanup(settings: settings)

        cleanup.performStartupCleanup()

        let remainingImages = try repository.fetchHistory(query: HistoryQuery(contentType: .image))
        XCTAssertEqual(remainingImages.map(\.id), [newImage.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldImage.fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldImage.thumbnailURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newImage.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newImage.thumbnailURL.path))
    }

    func testPerformStartupCleanup_whenImageCountExceedsLimitWithFavorite_shouldCountFavoriteTowardLimit() throws {
        var settings = UserDefaultsConfig(defaults: defaults)
        settings.maxImageHistoryCount = 2
        let oldestImage = try saveImage(name: "old-favorite-count", fileSize: 100)
        let favoriteImage = try saveImage(name: "favorite-count", fileSize: 100)
        let newestImage = try saveImage(name: "new-favorite-count", fileSize: 100)
        try repository.setFavorite(true, id: favoriteImage.id)
        try setCreatedAt(id: oldestImage.id, daysAgo: 3)
        try setCreatedAt(id: favoriteImage.id, daysAgo: 2)
        try setCreatedAt(id: newestImage.id, daysAgo: 1)
        let cleanup = makeCleanup(settings: settings)

        cleanup.performStartupCleanup()

        let remainingImages = try repository.fetchHistory(query: HistoryQuery(contentType: .image))
        XCTAssertEqual(Set(remainingImages.map(\.id)), [favoriteImage.id, newestImage.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldestImage.fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldestImage.thumbnailURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: favoriteImage.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newestImage.fileURL.path))
    }

    func testPerformStartupCleanup_whenImageStorageExceedsLimit_shouldDeleteOldestImagesAndFiles() throws {
        var settings = UserDefaultsConfig(defaults: defaults)
        settings.totalStorageCapInBytes = 250
        let oldestImage = try saveImage(name: "oldest-storage", fileSize: 200)
        let newestImage = try saveImage(name: "newest-storage", fileSize: 200)
        try setCreatedAt(id: oldestImage.id, daysAgo: 2)
        try setCreatedAt(id: newestImage.id, daysAgo: 1)
        let cleanup = makeCleanup(settings: settings)

        cleanup.performStartupCleanup()

        let remainingImages = try repository.fetchHistory(query: HistoryQuery(contentType: .image))
        XCTAssertEqual(remainingImages.map(\.id), [newestImage.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldestImage.fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldestImage.thumbnailURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newestImage.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newestImage.thumbnailURL.path))
    }

    private func makeCleanup(settings: UserDefaultsConfig) -> DataCleanupService {
        DataCleanupService(
            repository: repository,
            imageStorageService: ImageStorageService(imagesDirectory: imagesURL, thumbnailsDirectory: thumbnailsURL),
            settings: settings
        )
    }

    private func saveImage(name: String, fileSize: Int) throws -> (id: Int64, fileURL: URL, thumbnailURL: URL) {
        let fileURL = imagesURL.appendingPathComponent("\(name).png")
        let thumbnailURL = thumbnailsURL.appendingPathComponent("\(name)-thumb.png")
        try Data(repeating: 1, count: fileSize).write(to: fileURL)
        try Data(repeating: 2, count: 8).write(to: thumbnailURL)
        let storedImage = StoredClipboardImage(
            fileURL: fileURL,
            thumbnailURL: thumbnailURL,
            contentHash: "\(name)-hash",
            fileSize: fileSize,
            width: 16,
            height: 16,
            format: .png
        )
        let item = try repository.saveImage(storedImage, sourceApp: nil, sourceBundleID: nil)
        return (item.id, fileURL, thumbnailURL)
    }

    private func setCreatedAt(id: Int64, daysAgo: Int) throws {
        try database.execute(
            """
            UPDATE clipboard_history
            SET created_at = datetime('now', '-\(daysAgo) days'),
                updated_at = datetime('now', '-\(daysAgo) days')
            WHERE id = \(id);
            """
        )
    }
}
