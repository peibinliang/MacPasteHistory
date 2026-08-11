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

    func testPollOnce_whenForegroundAppChangesDuringTextCapture_shouldUseInitialSourceOnce() throws {
        let sourceProvider = SequencedSourceApplicationProvider(sources: [
            SourceApplication(name: "Password Manager", bundleID: "com.example.password-manager"),
            SourceApplication(name: "Browser", bundleID: "com.example.browser")
        ])
        let monitor = makeMonitor(sourceApplicationProvider: sourceProvider)
        _ = pasteboard.setString("non-sensitive account note", forType: .string)

        monitor.pollOnce()

        let item = try XCTUnwrap(repository.fetchTextHistory(matching: nil).first)
        let events = try repository.fetchCaptureEvents(historyID: item.id, since: .distantPast)
        XCTAssertEqual(sourceProvider.callCount, 1)
        XCTAssertEqual(item.sourceApp, "Password Manager")
        XCTAssertEqual(item.sourceBundleID, "com.example.password-manager")
        XCTAssertEqual(events.first?.sourceApp, item.sourceApp)
        XCTAssertEqual(events.first?.sourceBundleID, item.sourceBundleID)
    }

    func testPollOnce_whenTextIsSQLOrShell_shouldPersistCompleteClassification() throws {
        let monitor = makeMonitor()
        _ = pasteboard.setString("SELECT id FROM users WHERE active = 1", forType: .string)

        monitor.pollOnce()

        XCTAssertEqual(try repository.fetchTextHistory(matching: nil).first?.detectedType, .sql)
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

    func testPollOnce_whenForegroundAppChangesDuringImageCapture_shouldUseInitialSourceOnce() throws {
        let sourceProvider = SequencedSourceApplicationProvider(sources: [
            SourceApplication(name: "Preview", bundleID: "com.apple.Preview"),
            SourceApplication(name: "Browser", bundleID: "com.example.browser")
        ])
        let monitor = makeMonitor(sourceApplicationProvider: sourceProvider)
        _ = pasteboard.setData(try makePNGData(), forType: .png)

        monitor.pollOnce()

        let item = try XCTUnwrap(repository.fetchHistory(query: HistoryQuery(contentType: .image)).first)
        let events = try repository.fetchCaptureEvents(historyID: item.id, since: .distantPast)
        XCTAssertEqual(sourceProvider.callCount, 1)
        XCTAssertEqual(item.sourceApp, "Preview")
        XCTAssertEqual(item.sourceBundleID, "com.apple.Preview")
        XCTAssertEqual(events.first?.sourceApp, item.sourceApp)
        XCTAssertEqual(events.first?.sourceBundleID, item.sourceBundleID)
    }

    func testPollOnce_whenImageRecordingDisabled_shouldSkipSavingImage() throws {
        let monitor = makeMonitor(recordingSettings: StubRecordingSettings(shouldRecordText: true, shouldRecordImage: false))
        _ = pasteboard.setData(try makePNGData(), forType: .png)

        monitor.pollOnce()

        XCTAssertTrue(try repository.fetchHistory(query: HistoryQuery(contentType: .image)).isEmpty)
    }

    func testPollOnce_whenRecordingPausedInConfig_shouldSkipSavingText() throws {
        let suiteName = "ClipboardMonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        var config = UserDefaultsConfig(defaults: defaults)
        config.recordingPaused = true
        let monitor = makeMonitor(privacyService: PrivacyService(config: config))
        _ = pasteboard.setString("paused text", forType: .string)

        monitor.pollOnce()

        XCTAssertTrue(try repository.fetchTextHistory(matching: nil).isEmpty)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPollOnce_whenSourceAppIsBlockedInConfig_shouldSkipSavingText() throws {
        let suiteName = "ClipboardMonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        var config = UserDefaultsConfig(defaults: defaults)
        config.blockedApps = [
            BlockedAppEntry(bundleID: "com.peibin.tests", displayName: "Unit Test Host", isEnabled: true)
        ]
        let monitor = makeMonitor(privacyService: PrivacyService(config: config))
        _ = pasteboard.setString("blocked text", forType: .string)

        monitor.pollOnce()

        XCTAssertTrue(try repository.fetchTextHistory(matching: nil).isEmpty)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPollOnce_whenBlockedSourceLosesForegroundDuringCapture_shouldStillSkipUsingInitialSource() throws {
        let suiteName = "ClipboardMonitorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var config = UserDefaultsConfig(defaults: defaults)
        config.blockedApps = [
            BlockedAppEntry(
                bundleID: "com.example.password-manager",
                displayName: "Password Manager",
                isEnabled: true
            )
        ]
        let sourceProvider = SequencedSourceApplicationProvider(sources: [
            SourceApplication(name: "Password Manager", bundleID: "com.example.password-manager"),
            SourceApplication(name: "Browser", bundleID: "com.example.browser")
        ])
        let monitor = makeMonitor(
            privacyService: PrivacyService(config: config),
            sourceApplicationProvider: sourceProvider
        )
        _ = pasteboard.setString("blocked source text", forType: .string)

        monitor.pollOnce()

        XCTAssertEqual(sourceProvider.callCount, 1)
        XCTAssertTrue(try repository.fetchTextHistory(matching: nil).isEmpty)
    }

    func testPollOnce_whenSensitiveFilteringEnabled_shouldSkipBearerText() throws {
        let (config, cleanup) = makePrivacyConfig(filterSensitiveContent: true)
        defer { cleanup() }
        let monitor = makeMonitor(privacyService: PrivacyService(config: config))
        _ = pasteboard.setString(
            "curl -H 'Authorization: Bearer TESTTOKEN0123456789ABCDEF0123456789' https://example.invalid",
            forType: .string
        )

        monitor.pollOnce()

        XCTAssertTrue(try repository.fetchTextHistory(matching: nil).isEmpty)
    }

    func testPollOnce_whenSensitiveFilteringDisabled_shouldSaveMultilineCurlExactly() throws {
        let text = """
        curl -X POST 'https://example.invalid/completion' -H 'Authorization: Bearer TESTTOKEN0123456789ABCDEF0123456789' -d '{
          "input": { "prompt": "你好" }, "parameters": {}
        }';
        """
        let (config, cleanup) = makePrivacyConfig(filterSensitiveContent: false)
        defer { cleanup() }
        let monitor = makeMonitor(privacyService: PrivacyService(config: config))
        _ = pasteboard.setString(text, forType: .string)

        monitor.pollOnce()

        XCTAssertEqual(try repository.fetchTextHistory(matching: nil).first?.textContent, text)
    }

    func testPollOnce_whenSensitiveFilteringDisabled_shouldSaveLongDocumentationExactly() throws {
        let text = String(repeating: "钉钉机器人文档 https://example.invalid/send?access_token=xxxxx 😊\n", count: 80)
        let (config, cleanup) = makePrivacyConfig(filterSensitiveContent: false)
        defer { cleanup() }
        let monitor = makeMonitor(privacyService: PrivacyService(config: config))
        _ = pasteboard.setString(text, forType: .string)

        monitor.pollOnce()

        XCTAssertEqual(
            try repository.fetchTextHistory(matching: nil).first?.textContent,
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func makeMonitor() -> ClipboardMonitor {
        makeMonitor(recordingSettings: StubRecordingSettings(shouldRecordText: true, shouldRecordImage: true))
    }

    private func makeMonitor(recordingSettings: RecordingSettingsProviding) -> ClipboardMonitor {
        makeMonitor(recordingSettings: recordingSettings, privacyService: PrivacyService())
    }

    private func makeMonitor(sourceApplicationProvider: SourceApplicationProviding) -> ClipboardMonitor {
        makeMonitor(
            privacyService: PrivacyService(),
            sourceApplicationProvider: sourceApplicationProvider
        )
    }

    private func makeMonitor(
        recordingSettings: RecordingSettingsProviding = StubRecordingSettings(shouldRecordText: true, shouldRecordImage: true),
        privacyService: PrivacyService,
        sourceApplicationProvider: SourceApplicationProviding = StubSourceApplicationProvider()
    ) -> ClipboardMonitor {
        ClipboardMonitor(
            pasteboard: pasteboard,
            repository: repository,
            imageStorageService: imageStorageService,
            sourceApplicationProvider: sourceApplicationProvider,
            restorationState: restorationState,
            recordingSettings: recordingSettings,
            privacyService: privacyService,
            logger: Logger(category: "ClipboardMonitorTests")
        )
    }

    private func makePrivacyConfig(filterSensitiveContent: Bool) -> (UserDefaultsConfig, () -> Void) {
        let suiteName = "ClipboardMonitorTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        var config = UserDefaultsConfig(defaults: defaults)
        config.filterSensitiveContent = filterSensitiveContent

        return (config, { defaults.removePersistentDomain(forName: suiteName) })
    }

    private func makePNGData() throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 12,
            pixelsHigh: 8,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw TestImageError.encodingFailed
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.systemOrange.setFill()
        NSRect(x: 0, y: 0, width: 12, height: 8).fill()
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
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

private final class SequencedSourceApplicationProvider: SourceApplicationProviding {
    private let sources: [SourceApplication]
    private(set) var callCount = 0

    init(sources: [SourceApplication]) {
        self.sources = sources
    }

    func currentSourceApplication() -> SourceApplication {
        defer { callCount += 1 }
        guard sources.indices.contains(callCount) else {
            return sources.last ?? SourceApplication(name: nil, bundleID: nil)
        }
        return sources[callCount]
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
