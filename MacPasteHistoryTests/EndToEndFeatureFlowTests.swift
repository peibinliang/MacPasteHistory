import XCTest
@testable import MacPasteHistory

final class EndToEndFeatureFlowTests: XCTestCase {
    private var database: TemporaryDatabase!
    private var repository: ClipboardHistoryRepository!

    override func setUpWithError() throws {
        database = try TemporaryDatabase()
        try MigrationManager(database: database.connection).migrate()
        repository = ClipboardHistoryRepository(database: database.connection)
    }

    override func tearDownWithError() throws {
        repository = nil
        database?.remove()
        database = nil
    }

    func testStructuredActionDerivedUsageAndOCRSearchFlow() async throws {
        let source = try repository.saveText("eyJmb28iOiJiYXIifQ==", sourceApp: "Terminal", sourceBundleID: "com.apple.Terminal")
        try repository.updateDetectedType(id: source.id, result: ContentClassifier().classifyFast(source.textContent))

        let decoded = try Base64ContentAction(kind: .decode).execute(input: source.textContent)
        let formatted = try JSONContentAction(kind: .format).execute(input: decoded.output)
        var session = ActionSession(sourceItem: source)
        session.append(action: Base64ContentAction(kind: .decode), result: decoded, input: source.textContent)
        session.append(action: JSONContentAction(kind: .format), result: formatted, input: decoded.output)
        session.updateEditedOutput("{\n  \"foo\" : \"edited\"\n}")

        let derived = try repository.saveDerivedText(DerivedClipboardRecordRequest(
            text: session.currentOutput,
            sourceHistoryID: source.id,
            actionID: JSONContentAction(kind: .format).id.rawValue,
            actionSummary: session.actionSummary,
            sourcePreview: DerivedSourcePreviewBuilder.build(for: source),
            sourceHash: source.contentHash,
            detection: ContentClassifier().classifyFast(session.currentOutput)
        ))
        try repository.recordReuseCopy(historyID: derived.id, at: Date())
        try repository.deleteItem(id: source.id)

        let preservedDerived = try XCTUnwrap(repository.historyItem(id: derived.id))
        XCTAssertNil(preservedDerived.derivedFromHistoryID)
        XCTAssertEqual(preservedDerived.derivedActionSummary, "base64.decode → json.format")
        XCTAssertEqual(preservedDerived.reuseCopyCount, 1)

        let image = try repository.saveImage(StoredClipboardImage(fileURL: URL(fileURLWithPath: "/tmp/e2e-ocr.png"), thumbnailURL: URL(fileURLWithPath: "/tmp/e2e-ocr-thumb.png"), contentHash: "e2e-image", fileSize: 1, width: 1, height: 1, format: .png), sourceApp: nil, sourceBundleID: nil)
        try repository.saveOCRResult(id: image.id, text: "OCR searchable invoice", detection: ContentClassifier().classifyFast("OCR searchable invoice"))
        let provider = SearchCandidateProvider(databaseURL: database.url)
        let request = SearchCandidateRequest(parsedQuery: SearchQueryParser().parse("invoice type:image"), storageContentType: .image, sourceFilter: .all, timeRange: .all, favoritesOnly: false, limit: 20)

        let results = try await provider.candidates(for: request)
        XCTAssertEqual(results.map(\.id), [image.id])
    }
}
