import XCTest

@testable import MacPasteHistory

final class SearchCandidateProviderTests: XCTestCase {
    private var temporaryDatabase: TemporaryDatabase!
    private var repository: ClipboardHistoryRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDatabase = try TemporaryDatabase()
        try MigrationManager(database: temporaryDatabase.connection).migrate()
        repository = ClipboardHistoryRepository(database: temporaryDatabase.connection)
    }

    override func tearDownWithError() throws {
        repository = nil
        temporaryDatabase?.remove()
        temporaryDatabase = nil
        try super.tearDownWithError()
    }

    func testCandidates_returnsOnlyRowsMatchingTextTypeSourceAndFavoriteFilters() async throws {
        let terminalJSON = try repository.saveText(
            "search deployment manifest",
            sourceApp: "Terminal",
            sourceBundleID: "com.apple.Terminal"
        )
        try repository.updateDetectedType(
            id: terminalJSON.id,
            result: ContentDetectionResult(type: .json, confidence: 0.9, version: 1, detectedAt: Date())
        )
        try repository.setFavorite(true, id: terminalJSON.id)
        _ = try repository.saveText(
            "different deployment manifest",
            sourceApp: "Notes",
            sourceBundleID: "com.apple.Notes"
        )

        let request = SearchCandidateRequest(
            parsedQuery: SearchQueryParser().parse("deployment type:json app:terminal fav:true"),
            storageContentType: nil,
            sourceFilter: HistoryQuery.SourceFilter(appName: "terminal", bundleID: nil),
            timeRange: .all,
            favoritesOnly: true,
            limit: 50
        )
        let provider = SearchCandidateProvider(databaseURL: temporaryDatabase.url)

        let candidates = try await provider.candidates(for: request)

        XCTAssertEqual(candidates.map(\.id), [terminalJSON.id])
    }

    func testCandidates_usesIndependentReadOnlyConnectionForMigratedDatabase() async throws {
        let saved = try repository.saveText("independent reader", sourceApp: nil, sourceBundleID: nil)
        let provider = SearchCandidateProvider(databaseURL: temporaryDatabase.url)
        let request = SearchCandidateRequest(
            parsedQuery: SearchQueryParser().parse("independent"),
            storageContentType: .text,
            sourceFilter: .all,
            timeRange: .all,
            favoritesOnly: false,
            limit: 10
        )

        let candidates = try await provider.candidates(for: request)

        XCTAssertEqual(candidates.map(\.id), [saved.id])
    }
}
