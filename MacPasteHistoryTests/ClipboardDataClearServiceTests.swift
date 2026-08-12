import AppKit
import XCTest
@testable import MacPasteHistory

final class ClipboardDataClearServiceTests: XCTestCase {
    private var databaseURL: URL!
    private var database: DatabaseConnection!
    private var repository: ClipboardHistoryRepository!
    private var imageRootURL: URL!
    private var imagesURL: URL!
    private var thumbnailsURL: URL!
    private var imageStorageService: ImageStorageService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        database = try DatabaseConnection(databaseURL: databaseURL)
        try MigrationManager(database: database).migrate()
        repository = ClipboardHistoryRepository(database: database)
        imageRootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        imagesURL = imageRootURL.appendingPathComponent("images", isDirectory: true)
        thumbnailsURL = imageRootURL.appendingPathComponent("thumbnails", isDirectory: true)
        imageStorageService = ImageStorageService(imagesDirectory: imagesURL, thumbnailsDirectory: thumbnailsURL)
    }

    override func tearDownWithError() throws {
        imageStorageService = nil
        try? FileManager.default.removeItem(at: imageRootURL)
        imageRootURL = nil
        thumbnailsURL = nil
        imagesURL = nil
        repository = nil
        try database?.close()
        database = nil
        if let databaseURL {
            try? FileManager.default.removeItem(at: databaseURL)
        }
        databaseURL = nil
        try super.tearDownWithError()
    }

    func testClearAllData_shouldDeleteDatabaseRecordsAndImageFiles() throws {
        _ = try repository.saveText("clear all text", sourceApp: nil, sourceBundleID: nil)
        let imageItem = try saveImageRecord()
        let filePath = try XCTUnwrap(imageItem.filePath)
        let thumbnailPath = try XCTUnwrap(imageItem.thumbnailPath)
        let service = ClipboardDataClearService(
            repository: repository,
            imageStorageService: imageStorageService,
            aiTokenUsageRepository: AITokenUsageRepository(database: database)
        )

        let usageRepository = AITokenUsageRepository(database: database)
        try usageRepository.insert(AITokenUsageRecord(
            requestID: "clear-usage",
            provider: "deepseek",
            modelIdentifier: "deepseek-v4-flash",
            inputTokens: 4,
            outputTokens: 2,
            totalTokens: 6,
            cachedInputTokens: nil,
            createdAt: Date()
        ))
        let usageChange = expectation(forNotification: .aiTokenUsageDidChange, object: nil)

        try service.clearAllData()
        wait(for: [usageChange], timeout: 1)

        XCTAssertTrue(try repository.fetchHistory(query: HistoryQuery()).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbnailPath))
        XCTAssertTrue((try FileManager.default.contentsOfDirectory(atPath: imagesURL.path)).isEmpty)
        XCTAssertTrue((try FileManager.default.contentsOfDirectory(atPath: thumbnailsURL.path)).isEmpty)
        XCTAssertEqual(try usageRepository.summary(), .zero)
    }

    func testClearAllData_whenTokenDeletionFails_shouldStillDeleteImageFiles() throws {
        let imageItem = try saveImageRecord()
        let filePath = try XCTUnwrap(imageItem.filePath)
        let thumbnailPath = try XCTUnwrap(imageItem.thumbnailPath)
        let service = ClipboardDataClearService(
            repository: repository,
            imageStorageService: imageStorageService,
            aiTokenUsageRepository: FailingAITokenUsageDeleter()
        )
        let usageChange = expectation(forNotification: .aiTokenUsageDidChange, object: nil)
        usageChange.isInverted = true

        XCTAssertThrowsError(try service.clearAllData())
        wait(for: [usageChange], timeout: 0.1)

        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbnailPath))
    }

    private func saveImageRecord() throws -> ClipboardHistoryItem {
        let candidate = ClipboardImageCandidate(pngData: try makePNGData(), width: 8, height: 8, format: .png)
        let storedImage = try imageStorageService.storeImage(candidate)
        return try repository.saveImage(storedImage, sourceApp: nil, sourceBundleID: nil)
    }

    private func makePNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw TestImageEncodingError.encodingFailed
        }
        return pngData
    }
}

private enum TestImageEncodingError: Error {
    case encodingFailed
}

private struct FailingAITokenUsageDeleter: AITokenUsageDeleting {
    func deleteAll() throws {
        throw FailingAITokenUsageDeletionError.failed
    }
}

private enum FailingAITokenUsageDeletionError: Error {
    case failed
}
