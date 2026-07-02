import AppKit
import XCTest
@testable import MacPasteHistory

final class ClipboardMonitorTests: XCTestCase {
    private var pasteboard: FakePasteboard!
    private var databaseURL: URL!
    private var database: DatabaseConnection!
    private var repository: ClipboardHistoryRepository!
    private var restorationState: ClipboardRestorationState!
    private var imageRootURL: URL!
    private var imageStorageService: ImageStorageService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        pasteboard = FakePasteboard()
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        database = try DatabaseConnection(databaseURL: databaseURL)
        try MigrationManager(database: database).migrate()
        repository = ClipboardHistoryRepository(database: database)
        restorationState = ClipboardRestorationState()
        imageRootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        imageStorageService = ImageStorageService(
            imagesDirectory: imageRootURL.appendingPathComponent("images", isDirectory: true),
            thumbnailsDirectory: imageRootURL.appendingPathComponent("thumbnails", isDirectory: true)
        )
    }

    override func tearDownWithError() throws {
        imageStorageService = nil
        if let imageRootURL {
            try? FileManager.default.removeItem(at: imageRootURL)
        }
        imageRootURL = nil
        repository = nil
        restorationState = nil
        try database?.close()
        database = nil
        if let databaseURL {
            try? FileManager.default.removeItem(at: databaseURL)
        }
        databaseURL = nil
        pasteboard = nil
        try super.tearDownWithError()
    }

    func testPollOnce_whenPasteboardChangeCountChanges_shouldSaveTextWithSourceMetadata() throws {
        let monitor = makeMonitor()
        _ = pasteboard.setString("monitored text", forType: .string)

        monitor.pollOnce()

        let items = try repository.fetchTextHistory(matching: nil)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.textContent, "monitored text")
        XCTAssertEqual(items.first?.sourceApp, "Unit Test Host")
        XCTAssertEqual(items.first?.sourceBundleID, "com.peibin.tests")
    }

    func testPollOnce_whenPasteboardDoesNotChange_shouldNotSaveDuplicateText() throws {
        let monitor = makeMonitor()
        _ = pasteboard.setString("single change", forType: .string)

        monitor.pollOnce()
        monitor.pollOnce()

        XCTAssertEqual(try repository.fetchTextHistory(matching: nil).count, 1)
    }

    func testPollOnce_whenChangeWasInternalRestore_shouldSkipSavingText() throws {
        let monitor = makeMonitor()
        restorationState.markNextChangeShouldBeSkipped()
        _ = pasteboard.setString("restored internally", forType: .string)

        monitor.pollOnce()

        XCTAssertTrue(try repository.fetchTextHistory(matching: nil).isEmpty)
    }

    func testPollOnce_whenPasteboardContainsImage_shouldSaveImageWithFilesAndMetadata() throws {
        let monitor = makeMonitor()
        let pngData = try makePNGData()
        _ = pasteboard.setData(pngData, forType: .png)

        monitor.pollOnce()

        let items = try repository.fetchHistory(query: HistoryQuery(contentType: .image))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.contentType, .image)
        XCTAssertEqual(items.first?.sourceApp, "Unit Test Host")
        XCTAssertEqual(items.first?.imageFormat, .png)
        XCTAssertEqual(items.first?.imageWidth, 12)
        XCTAssertEqual(items.first?.imageHeight, 8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: items.first?.filePath ?? ""))
        XCTAssertTrue(FileManager.default.fileExists(atPath: items.first?.thumbnailPath ?? ""))
    }

    func testPollOnce_whenImageRecordingDisabled_shouldSkipSavingImage() throws {
        let monitor = makeMonitor(recordingSettings: StubRecordingSettings(shouldRecordText: true, shouldRecordImage: false))
        _ = pasteboard.setData(try makePNGData(), forType: .png)

        monitor.pollOnce()

        XCTAssertTrue(try repository.fetchHistory(query: HistoryQuery(contentType: .image)).isEmpty)
    }

    private func makeMonitor() -> ClipboardMonitor {
        makeMonitor(recordingSettings: StubRecordingSettings(shouldRecordText: true, shouldRecordImage: true))
    }

    private func makeMonitor(recordingSettings: RecordingSettingsProviding) -> ClipboardMonitor {
        ClipboardMonitor(
            pasteboard: pasteboard,
            repository: repository,
            imageStorageService: imageStorageService,
            sourceApplicationProvider: StubSourceApplicationProvider(),
            restorationState: restorationState,
            recordingSettings: recordingSettings,
            logger: Logger(category: "ClipboardMonitorTests")
        )
    }

    private func makePNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 12, height: 8))
        image.lockFocus()
        NSColor.systemOrange.setFill()
        NSRect(x: 0, y: 0, width: 12, height: 8).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw TestImageError.encodingFailed
        }
        return pngData
    }
}

private struct StubSourceApplicationProvider: SourceApplicationProviding {
    func currentSourceApplication() -> SourceApplication {
        SourceApplication(name: "Unit Test Host", bundleID: "com.peibin.tests")
    }
}

private struct StubRecordingSettings: RecordingSettingsProviding {
    let shouldRecordText: Bool
    let shouldRecordImage: Bool
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

    func image() -> NSImage? {
        nil
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        values[dataType] = string
        changeCount += 1
        return true
    }
}
