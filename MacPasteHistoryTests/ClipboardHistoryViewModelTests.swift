import AppKit
import XCTest
@testable import MacPasteHistory

@MainActor
final class ClipboardHistoryViewModelTests: XCTestCase {
    private var databaseURL: URL!
    private var database: DatabaseConnection!
    private var repository: ClipboardHistoryRepository!
    private var viewModel: ClipboardHistoryViewModel!
    private var pasteboard: FakePasteboard!
    private var imageRootURL: URL!
    private var imageStorageService: ImageStorageService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        database = try DatabaseConnection(databaseURL: databaseURL)
        try MigrationManager(database: database).migrate()
        repository = ClipboardHistoryRepository(database: database)
        pasteboard = FakePasteboard()
        imageRootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        imageStorageService = ImageStorageService(
            imagesDirectory: imageRootURL.appendingPathComponent("images", isDirectory: true),
            thumbnailsDirectory: imageRootURL.appendingPathComponent("thumbnails", isDirectory: true)
        )
        let writer = ClipboardWriter(pasteboard: pasteboard, restorationState: ClipboardRestorationState())
        viewModel = ClipboardHistoryViewModel(
            repository: repository,
            writer: writer,
            imageStorageService: imageStorageService,
            pageSize: 2
        )
    }

    override func tearDownWithError() throws {
        viewModel = nil
        imageStorageService = nil
        if let imageRootURL {
            try? FileManager.default.removeItem(at: imageRootURL)
        }
        imageRootURL = nil
        pasteboard = nil
        repository = nil
        try database?.close()
        database = nil
        if let databaseURL {
            try? FileManager.default.removeItem(at: databaseURL)
        }
        databaseURL = nil
        try super.tearDownWithError()
    }

    func testLoadMore_whenMoreItemsExist_shouldAppendNextPage() throws {
        _ = try repository.saveText("first", sourceApp: nil, sourceBundleID: nil)
        Thread.sleep(forTimeInterval: 0.01)
        _ = try repository.saveText("second", sourceApp: nil, sourceBundleID: nil)
        Thread.sleep(forTimeInterval: 0.01)
        _ = try repository.saveText("third", sourceApp: nil, sourceBundleID: nil)

        viewModel.loadHistory()
        XCTAssertEqual(viewModel.items.map(\.textContent), ["third", "second"])

        viewModel.loadMoreIfNeeded(currentItem: viewModel.items.last)

        XCTAssertEqual(viewModel.items.map(\.textContent), ["third", "second", "first"])
    }

    func testToggleFavorite_shouldRefreshFavoriteState() throws {
        let item = try repository.saveText("favorite from view model", sourceApp: nil, sourceBundleID: nil)
        viewModel.loadHistory()

        viewModel.toggleFavorite(item)

        XCTAssertEqual(viewModel.items.first?.isFavorite, true)
    }

    func testFavoritesOnlyFilter_shouldShowOnlyFavoriteItems() throws {
        let favorite = try repository.saveText("favorite", sourceApp: nil, sourceBundleID: nil)
        _ = try repository.saveText("ordinary", sourceApp: nil, sourceBundleID: nil)
        try repository.setFavorite(true, id: favorite.id)

        viewModel.isFavoritesOnly = true
        viewModel.loadHistory()

        XCTAssertEqual(viewModel.items.map(\.textContent), ["favorite"])
    }

    func testContentTypeFilter_whenImageSelected_shouldHideTextItems() throws {
        _ = try repository.saveText("text", sourceApp: nil, sourceBundleID: nil)

        viewModel.selectedContentType = .image
        viewModel.loadHistory()

        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testRestore_whenItemIsImage_shouldWriteImageDataToPasteboard() throws {
        let pngData = try makePNGData()
        let item = try saveImageRecord(pngData: pngData)

        viewModel.restore(item)

        XCTAssertEqual(pasteboard.data(forType: .png), pngData)
    }

    func testDelete_whenItemIsImage_shouldRemoveDatabaseRecordAndImageFiles() throws {
        let item = try saveImageRecord(pngData: makePNGData())
        let filePath = try XCTUnwrap(item.filePath)
        let thumbnailPath = try XCTUnwrap(item.thumbnailPath)

        viewModel.delete(item)

        XCTAssertTrue(try repository.fetchHistory(query: HistoryQuery(contentType: .image)).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbnailPath))
    }

    private func saveImageRecord(pngData: Data) throws -> ClipboardHistoryItem {
        let candidate = ClipboardImageCandidate(pngData: pngData, width: 8, height: 8, format: .png)
        let storedImage = try imageStorageService.storeImage(candidate)
        return try repository.saveImage(storedImage, sourceApp: nil, sourceBundleID: nil)
    }

    private func makePNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemPurple.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw TestImageError.encodingFailed
        }
        return pngData
    }
}

private enum TestImageError: Error {
    case encodingFailed
}

private final class FakePasteboard: PasteboardProviding {
    private var values: [NSPasteboard.PasteboardType: String] = [:]
    private var dataValues: [NSPasteboard.PasteboardType: Data] = [:]
    private(set) var changeCount = 0

    func data(forType dataType: NSPasteboard.PasteboardType) -> Data? {
        dataValues[dataType]
    }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        values[dataType]
    }

    func fileURLs() -> [URL] {
        []
    }

    func clearContents() -> Int {
        values.removeAll()
        dataValues.removeAll()
        changeCount += 1
        return changeCount
    }

    func setData(_ data: Data?, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        guard let data else {
            return false
        }
        dataValues[dataType] = data
        changeCount += 1
        return true
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        values[dataType] = string
        changeCount += 1
        return true
    }
}
