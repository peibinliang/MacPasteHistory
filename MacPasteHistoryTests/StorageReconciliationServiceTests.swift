import AppKit
import XCTest
@testable import MacPasteHistory

final class StorageReconciliationServiceTests: XCTestCase {
    private var rootURL: URL!
    private var imagesURL: URL!
    private var thumbnailsURL: URL!
    private var temporaryURL: URL!
    private var database: DatabaseConnection!
    private var repository: ClipboardHistoryRepository!
    private var now: Date!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        imagesURL = rootURL.appendingPathComponent("images", isDirectory: true)
        thumbnailsURL = rootURL.appendingPathComponent("thumbnails", isDirectory: true)
        temporaryURL = rootURL.appendingPathComponent("temporary", isDirectory: true)
        for directory in [imagesURL, thumbnailsURL, temporaryURL] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        database = try DatabaseConnection(databaseURL: rootURL.appendingPathComponent("clipboard.sqlite"))
        try MigrationManager(database: database).migrate()
        repository = ClipboardHistoryRepository(database: database)
        now = Date(timeIntervalSince1970: 2_000_000_000)
    }

    override func tearDownWithError() throws {
        repository = nil
        try database?.close()
        database = nil
        if let rootURL {
            try? FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        imagesURL = nil
        thumbnailsURL = nil
        temporaryURL = nil
        now = nil
        try super.tearDownWithError()
    }

    func testMakePlan_whenOriginalIsMissing_shouldRetainRecordAndClassifyIssue() throws {
        let item = try saveImageRecord(name: "missing-original", originalData: nil, thumbnailData: validPNGData())

        let plan = try makePlan()

        XCTAssertTrue(plan.issues.contains { $0.kind == .missingOriginal && $0.historyID == item.id })
        XCTAssertFalse(plan.actions.contains { $0.historyID == item.id })
        XCTAssertNotNil(try repository.historyItem(id: item.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.thumbnailPath ?? ""))
    }

    func testMakePlan_whenManagedFilesAreUnreferenced_shouldClassifyAndRetainOrphans() throws {
        let orphanOriginal = imagesURL.appendingPathComponent("orphan.png")
        let orphanThumbnail = thumbnailsURL.appendingPathComponent("orphan.png")
        try validPNGData().write(to: orphanOriginal)
        try validPNGData().write(to: orphanThumbnail)

        let plan = try makePlan()

        XCTAssertTrue(plan.issues.contains { $0.kind == .orphanedManagedOriginal })
        XCTAssertTrue(plan.issues.contains { $0.kind == .orphanedManagedThumbnail })
        XCTAssertTrue(
            plan.actions.allSatisfy { $0.kind == .regenerateThumbnail || $0.kind == .deleteStaleTemporaryFile }
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanOriginal.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanThumbnail.path))
    }

    func testMakePlan_whenThumbnailIsMissingAndOriginalIsValid_shouldPlanRegeneration() throws {
        let item = try saveImageRecord(name: "missing-thumbnail", originalData: validPNGData(), thumbnailData: nil)

        let plan = try makePlan()

        XCTAssertTrue(plan.issues.contains { $0.kind == .missingThumbnail && $0.historyID == item.id })
        XCTAssertTrue(plan.actions.contains { $0.kind == .regenerateThumbnail && $0.historyID == item.id })
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.thumbnailPath ?? ""))
    }

    func testMakePlan_whenOneOriginalIsCorrupted_shouldRetainItAndContinueOtherItems() throws {
        let corrupted = try saveImageRecord(
            name: "corrupted",
            originalData: Data("not an image".utf8),
            thumbnailData: validPNGData()
        )
        let repairable = try saveImageRecord(name: "repairable", originalData: validPNGData(), thumbnailData: nil)

        let plan = try makePlan()

        XCTAssertTrue(plan.issues.contains { $0.kind == .corruptedOriginal && $0.historyID == corrupted.id })
        XCTAssertFalse(plan.actions.contains { $0.historyID == corrupted.id })
        XCTAssertTrue(plan.actions.contains { $0.kind == .regenerateThumbnail && $0.historyID == repairable.id })
        XCTAssertTrue(FileManager.default.fileExists(atPath: corrupted.filePath ?? ""))
        XCTAssertNotNil(try repository.historyItem(id: corrupted.id))
    }

    func testMakePlan_whenTemporaryFilesVaryByAgeAndProvenance_shouldDeleteOnlyStaleOwnedFile() throws {
        let staleOwned = temporaryURL.appendingPathComponent("mph-image-stale.tmp")
        let recentOwned = temporaryURL.appendingPathComponent("mph-image-recent.tmp")
        let staleUnowned = temporaryURL.appendingPathComponent("unowned.tmp")
        for file in [staleOwned, recentOwned, staleUnowned] {
            try Data("temporary".utf8).write(to: file)
        }
        try setModificationDate(now.addingTimeInterval(-25 * 60 * 60), for: staleOwned)
        try setModificationDate(now.addingTimeInterval(-23 * 60 * 60), for: recentOwned)
        try setModificationDate(now.addingTimeInterval(-25 * 60 * 60), for: staleUnowned)

        let plan = try makePlan()

        let tempDeletes = plan.actions.filter { $0.kind == .deleteStaleTemporaryFile }
        XCTAssertEqual(tempDeletes.map(\.fileURL), [staleOwned.standardizedFileURL])
        XCTAssertTrue(FileManager.default.fileExists(atPath: recentOwned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: staleUnowned.path))
    }

    func testMakePlan_whenRecordPathsAreOutsideManagedRoots_shouldReportUncertainOwnership() throws {
        let externalRoot = rootURL.appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(at: externalRoot, withIntermediateDirectories: true)
        let externalOriginal = externalRoot.appendingPathComponent("outside.png")
        let externalThumbnail = externalRoot.appendingPathComponent("outside-thumb.png")
        let item = try saveImageRecord(
            name: "outside",
            originalURL: externalOriginal,
            thumbnailURL: externalThumbnail,
            originalData: validPNGData(),
            thumbnailData: validPNGData()
        )

        let plan = try makePlan()

        XCTAssertTrue(plan.issues.contains { $0.kind == .uncertainOwnership && $0.historyID == item.id })
        XCTAssertFalse(plan.actions.contains { $0.historyID == item.id })
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalOriginal.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalThumbnail.path))
    }

    func testReconcile_whenRunTwice_shouldBeIdempotentAndRetainUncertainFiles() throws {
        let repairable = try saveImageRecord(name: "repeat", originalData: validPNGData(), thumbnailData: nil)
        let orphan = imagesURL.appendingPathComponent("retained-orphan.png")
        let staleTemporary = temporaryURL.appendingPathComponent("mph-image-repeat.tmp")
        try validPNGData().write(to: orphan)
        try Data("temporary".utf8).write(to: staleTemporary)
        try setModificationDate(now.addingTimeInterval(-25 * 60 * 60), for: staleTemporary)

        let firstReport = service().reconcile()
        let secondReport = service().reconcile()

        XCTAssertEqual(firstReport.completedActionCount, 2)
        XCTAssertEqual(firstReport.failedActionCount, 0)
        XCTAssertEqual(secondReport.completedActionCount, 0)
        XCTAssertEqual(secondReport.failedActionCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repairable.thumbnailPath ?? ""))
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleTemporary.path))
    }

    private func makePlan() throws -> StorageReconciliationPlan {
        let service = service()
        return service.makePlan(from: try service.scan())
    }

    private func service() -> StorageReconciliationService {
        let currentDate = now ?? Date(timeIntervalSince1970: 2_000_000_000)
        return StorageReconciliationService(
            repository: repository,
            imagesDirectory: imagesURL,
            thumbnailsDirectory: thumbnailsURL,
            temporaryDirectory: temporaryURL,
            now: { currentDate }
        )
    }

    @discardableResult
    private func saveImageRecord(
        name: String,
        originalURL: URL? = nil,
        thumbnailURL: URL? = nil,
        originalData: Data?,
        thumbnailData: Data?
    ) throws -> ClipboardHistoryItem {
        let resolvedOriginalURL = originalURL ?? imagesURL.appendingPathComponent("\(name).png")
        let resolvedThumbnailURL = thumbnailURL ?? thumbnailsURL.appendingPathComponent("\(name).png")
        if let originalData {
            try originalData.write(to: resolvedOriginalURL)
        }
        if let thumbnailData {
            try thumbnailData.write(to: resolvedThumbnailURL)
        }
        return try repository.saveImage(
            StoredClipboardImage(
                fileURL: resolvedOriginalURL,
                thumbnailURL: resolvedThumbnailURL,
                contentHash: "\(name)-hash",
                fileSize: originalData?.count ?? 0,
                width: 20,
                height: 12,
                format: .png
            ),
            sourceApp: nil,
            sourceBundleID: nil
        )
    }

    private func validPNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 20, height: 12))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 20, height: 12).fill()
        image.unlockFocus()
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw StorageReconciliationTestError.imageEncodingFailed
        }
        return data
    }

    private func setModificationDate(_ date: Date, for fileURL: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: fileURL.path)
    }
}

private enum StorageReconciliationTestError: Error {
    case imageEncodingFailed
}
