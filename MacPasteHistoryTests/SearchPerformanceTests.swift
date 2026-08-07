import XCTest

@testable import MacPasteHistory

final class SearchPerformanceTests: XCTestCase {
    func testRanker_processesFiveHundredInMemoryItemsWithinMeasuredInitialFilterTarget() {
        let ranker = SearchRanker()
        let items = (0..<500).map { index in
            item(id: Int64(index), text: "searchable record \(index) needle")
        }

        measure(metrics: [XCTClockMetric()]) {
            _ = ranker.rank(items: items, terms: ["needle"])
        }
    }

    func testCandidateQuery_readsFiveHundredRowsWithinMeasuredTarget() throws {
        let temporaryDatabase = try TemporaryDatabase()
        defer { temporaryDatabase.remove() }
        try MigrationManager(database: temporaryDatabase.connection).migrate()
        let repository = ClipboardHistoryRepository(database: temporaryDatabase.connection)
        for index in 0..<500 {
            _ = try repository.saveText("database searchable record \(index)", sourceApp: nil, sourceBundleID: nil)
        }
        let request = SearchCandidateRequest(
            parsedQuery: SearchQueryParser().parse("searchable"),
            storageContentType: .text,
            sourceFilter: .all,
            timeRange: .all,
            favoritesOnly: false,
            limit: 500
        )

        measure(metrics: [XCTClockMetric()]) {
            do {
                _ = try repository.fetchSearchCandidates(request: request)
            } catch {
                XCTFail("Candidate query failed: \(error)")
            }
        }
    }

    private func item(id: Int64, text: String) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: id,
            contentType: .text,
            textContent: text,
            filePath: nil,
            thumbnailPath: nil,
            sourceApp: nil,
            sourceBundleID: nil,
            contentHash: "hash-\(id)",
            textLength: text.count,
            fileSize: nil,
            imageWidth: nil,
            imageHeight: nil,
            imageFormat: nil,
            isFavorite: false,
            isSensitive: false,
            createdAt: Date(),
            updatedAt: Date(),
            searchableText: text
        )
    }
}
