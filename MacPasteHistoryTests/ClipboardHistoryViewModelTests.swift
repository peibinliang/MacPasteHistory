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

    func testLoadMore_withSearchCoordinatorBeforeAnySearchStillUsesRepositoryPagination() throws {
        _ = try repository.saveText("first", sourceApp: nil, sourceBundleID: nil)
        _ = try repository.saveText("second", sourceApp: nil, sourceBundleID: nil)
        _ = try repository.saveText("third", sourceApp: nil, sourceBundleID: nil)
        let writer = ClipboardWriter(pasteboard: pasteboard, restorationState: ClipboardRestorationState())
        viewModel = ClipboardHistoryViewModel(
            repository: repository,
            writer: writer,
            imageStorageService: imageStorageService,
            pageSize: 2,
            searchCoordinator: NoopSearchCoordinator()
        )

        viewModel.loadHistory()
        viewModel.loadMoreIfNeeded(currentItem: viewModel.items.last)

        XCTAssertEqual(viewModel.items.count, 3)
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

    func testSourceFilter_shouldShowOnlySelectedSource() throws {
        _ = try repository.saveText("safari", sourceApp: "Safari", sourceBundleID: "com.apple.Safari")
        _ = try repository.saveText("notes", sourceApp: "Notes", sourceBundleID: "com.apple.Notes")
        viewModel.loadHistory()

        viewModel.selectedSourceOption = HistorySourceOption(appName: "Safari", bundleID: "com.apple.Safari")
        viewModel.loadHistory()

        XCTAssertEqual(viewModel.items.map(\.textContent), ["safari"])
    }

    func testLoadHistory_whenSelectedSourceWasDeleted_shouldClearInvalidSourceSelection() throws {
        let item = try repository.saveText("safari", sourceApp: "Safari", sourceBundleID: "com.apple.Safari")
        viewModel.selectedSourceOption = HistorySourceOption(appName: "Safari", bundleID: "com.apple.Safari")

        try repository.deleteItem(id: item.id)
        viewModel.loadHistory()

        XCTAssertNil(viewModel.selectedSourceOption)
    }

    func testRestore_whenItemIsImage_shouldWriteImageDataToPasteboard() throws {
        let pngData = try makePNGData()
        let item = try saveImageRecord(pngData: pngData)

        XCTAssertTrue(viewModel.restore(item))

        XCTAssertEqual(pasteboard.data(forType: .png), pngData)
    }

    func testRestore_whenTextWriteSucceeds_shouldReturnTrue() throws {
        let item = try repository.saveText("double click paste text", sourceApp: nil, sourceBundleID: nil)

        let didRestore = viewModel.restore(item)

        XCTAssertTrue(didRestore)
        XCTAssertEqual(pasteboard.string(forType: .string), "double click paste text")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRestore_whenTextWriteFails_shouldReturnFalseAndExposeError() throws {
        let item = try repository.saveText("unwritable text", sourceApp: nil, sourceBundleID: nil)
        pasteboard.shouldFailStringWrites = true

        let didRestore = viewModel.restore(item)

        XCTAssertFalse(didRestore)
        XCTAssertEqual(viewModel.errorMessage, NSLocalizedString("Failed to restore text to clipboard.", comment: ""))
    }

    func testPasteRequest_whenImageFileIsMissing_shouldPreserveImageSpecificFeedback() throws {
        let pngData = try makePNGData()
        let item = try saveImageRecord(pngData: pngData)
        try FileManager.default.removeItem(atPath: try XCTUnwrap(item.filePath))

        XCTAssertNil(viewModel.pasteRequest(for: item))
        XCTAssertEqual(viewModel.errorMessage, NSLocalizedString("Failed to restore image to clipboard.", comment: ""))
    }

    func testApplyPasteOutcome_whenImageWriteAlreadyFailed_shouldNotReplaceSpecificFeedback() throws {
        let pngData = try makePNGData()
        let item = try saveImageRecord(pngData: pngData)
        try FileManager.default.removeItem(atPath: try XCTUnwrap(item.filePath))
        XCTAssertNil(viewModel.pasteRequest(for: item))

        viewModel.applyPasteOutcome(.failed(.clipboardWrite))

        XCTAssertEqual(viewModel.errorMessage, NSLocalizedString("Failed to restore image to clipboard.", comment: ""))
    }

    func testCopyActionOutput_whenWriteSucceeds_shouldRecordReuseCopy() throws {
        let source = try repository.saveText("source", sourceApp: nil, sourceBundleID: nil)

        XCTAssertTrue(viewModel.copyActionOutput("result", sourceItem: source))

        XCTAssertEqual(try historyItem(id: source.id).reuseCopyCount, 1)
        XCTAssertEqual(try historyItem(id: source.id).pasteCount, 0)
        XCTAssertEqual(pasteboard.string(forType: .string), "result")
    }

    func testPasteActionOutput_whenDispatchSucceeds_shouldRecordPasteOnly() throws {
        let source = try repository.saveText("source", sourceApp: nil, sourceBundleID: nil)

        XCTAssertTrue(viewModel.pasteActionOutput("result", sourceItem: source, pasteCommandService: PasteCommandService(sender: TestPasteCommandSender(didDispatch: true))))

        XCTAssertEqual(try historyItem(id: source.id).reuseCopyCount, 0)
        XCTAssertEqual(try historyItem(id: source.id).pasteCount, 1)
    }

    func testPasteActionOutput_whenDispatchFails_shouldRecordManualCopyOnly() throws {
        let source = try repository.saveText("source", sourceApp: nil, sourceBundleID: nil)

        XCTAssertFalse(viewModel.pasteActionOutput("result", sourceItem: source, pasteCommandService: PasteCommandService(sender: TestPasteCommandSender(didDispatch: false))))

        XCTAssertEqual(try historyItem(id: source.id).reuseCopyCount, 1)
        XCTAssertEqual(try historyItem(id: source.id).pasteCount, 0)
        XCTAssertEqual(viewModel.errorMessage, NSLocalizedString("Paste was not sent. Press Command-V to paste manually.", comment: ""))
    }

    func testSaveDerivedActionOutput_shouldPersistMetadataWithoutUsageIncrement() throws {
        let source = try repository.saveText("source", sourceApp: nil, sourceBundleID: nil)
        let action = TextContentAction(kind: .uppercase)
        let result = try action.execute(input: source.textContent)
        var session = ActionSession(sourceItem: source)
        session.append(action: action, result: result, input: source.textContent)

        let saved = try XCTUnwrap(viewModel.saveDerivedActionOutput(from: session))

        XCTAssertEqual(saved.textContent, "SOURCE")
        XCTAssertEqual(saved.derivedFromHistoryID, source.id)
        XCTAssertEqual(saved.derivedActionID, action.id.rawValue)
        XCTAssertEqual(saved.derivedActionSummary, action.titleKey)
        XCTAssertEqual(viewModel.selectedItemID, saved.id)
        XCTAssertEqual(try historyItem(id: source.id).reuseCopyCount, 0)
        XCTAssertEqual(try historyItem(id: source.id).pasteCount, 0)
    }

    func testSaveDerivedActionOutput_afterMovingBackPersistsCurrentStepMetadata() throws {
        let source = try repository.saveText("source", sourceApp: nil, sourceBundleID: nil)
        let first = TextContentAction(kind: .uppercase)
        let second = TextContentAction(kind: .markdownCodeBlock)
        var session = ActionSession(sourceItem: source)
        session.append(action: first, result: try first.execute(input: "source"), input: "source")
        session.append(action: second, result: try second.execute(input: "SOURCE"), input: "SOURCE")
        session.moveBack()

        let saved = try XCTUnwrap(viewModel.saveDerivedActionOutput(from: session))

        XCTAssertEqual(saved.textContent, "SOURCE")
        XCTAssertEqual(saved.derivedActionID, first.id.rawValue)
        XCTAssertEqual(saved.derivedActionSummary, first.titleKey)
    }

    func testSaveDerivedActionOutput_withEmptyEditedOutputDoesNotCreateRecord() throws {
        let source = try repository.saveText("source", sourceApp: nil, sourceBundleID: nil)
        let action = TextContentAction(kind: .uppercase)
        var session = ActionSession(sourceItem: source)
        session.append(action: action, result: try action.execute(input: "source"), input: "source")
        session.updateEditedOutput(" \n\t")

        XCTAssertNil(viewModel.saveDerivedActionOutput(from: session))
        XCTAssertEqual(try repository.fetchHistory(query: HistoryQuery(contentType: .text)).map(\.id), [source.id])
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

    func testDelete_whenItemIsText_shouldRefreshVisibleList() throws {
        let item = try repository.saveText("delete me", sourceApp: nil, sourceBundleID: nil)
        _ = try repository.saveText("keep me", sourceApp: nil, sourceBundleID: nil)
        viewModel.loadHistory()

        viewModel.delete(item)

        XCTAssertEqual(viewModel.items.map(\.textContent), ["keep me"])
    }

    func testClearTextHistory_shouldRemoveTextAndKeepImage() throws {
        _ = try repository.saveText("clear me", sourceApp: nil, sourceBundleID: nil)
        let image = try saveImageRecord(pngData: makePNGData())
        viewModel.loadHistory()

        viewModel.clearTextHistory()

        XCTAssertEqual(viewModel.items.map(\.id), [image.id])
    }

    private func saveImageRecord(pngData: Data) throws -> ClipboardHistoryItem {
        let candidate = ClipboardImageCandidate(pngData: pngData, width: 8, height: 8, format: .png)
        let storedImage = try imageStorageService.storeImage(candidate)
        return try repository.saveImage(storedImage, sourceApp: nil, sourceBundleID: nil)
    }

    private func historyItem(id: Int64) throws -> ClipboardHistoryItem {
        try XCTUnwrap(repository.fetchHistory(query: HistoryQuery()).first { $0.id == id })
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

private final class TestPasteCommandSender: PasteCommandSending {
    let didDispatch: Bool

    init(didDispatch: Bool) {
        self.didDispatch = didDispatch
    }

    func sendCommandVPaste() -> Bool {
        didDispatch
    }
}

private enum TestImageError: Error {
    case encodingFailed
}

private struct NoopSearchCoordinator: SearchCoordinating {
    func immediateResults(input: String, loadedItems: [ClipboardHistoryItem], filters: SearchUIFilters) async -> SearchResponse {
        SearchResponse(parsedQuery: SearchQueryParser().parse(input), results: [], isCurrent: true, errorDescription: nil)
    }

    func search(input: String, loadedItems: [ClipboardHistoryItem], filters: SearchUIFilters) async -> SearchResponse {
        SearchResponse(parsedQuery: SearchQueryParser().parse(input), results: [], isCurrent: true, errorDescription: nil)
    }

    func cancelCurrentSearch() async {}
}

private final class FakePasteboard: PasteboardProviding {
    private var values: [NSPasteboard.PasteboardType: String] = [:]
    private var dataValues: [NSPasteboard.PasteboardType: Data] = [:]
    var shouldFailStringWrites = false
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

    func image() -> NSImage? {
        nil
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        guard shouldFailStringWrites == false else {
            return false
        }
        values[dataType] = string
        changeCount += 1
        return true
    }
}
