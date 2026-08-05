import XCTest

@testable import MacPasteHistory

final class SearchCandidateSQLBuilderTests: XCTestCase {
    func testBuild_usesBoundValuesAndEffectiveTypeForStructuredFilters() {
        let referenceDate = Date(timeIntervalSince1970: 1_750_000_000)
        let request = request(
            input: "alpha O'Brien type:jwt app:Terminal fav:true before:7d after:30d",
            now: referenceDate,
            storageContentType: .text,
            sourceFilter: HistoryQuery.SourceFilter(appName: "Terminal", bundleID: "com.apple.Terminal"),
            timeRange: .last7Days,
            favoritesOnly: true,
            limit: 900
        )

        let query = SearchCandidateSQLBuilder(now: { referenceDate }).build(request: request)

        XCTAssertTrue(query.sql.contains("COALESCE(user_override_type, detected_type, CASE WHEN content_type = 'image' THEN 'image' ELSE 'plainText' END)"))
        XCTAssertTrue(query.sql.contains("last_captured_at"))
        XCTAssertTrue(query.sql.contains("LOWER(COALESCE(source_app, ''))"))
        XCTAssertTrue(query.sql.contains("LOWER(COALESCE(source_bundle_id, ''))"))
        XCTAssertTrue(query.sql.contains("CASE WHEN"))
        XCTAssertTrue(query.sql.contains("LIMIT ?"))
        XCTAssertFalse(query.sql.contains("O'Brien"))
        XCTAssertEqual(query.bindings.last, .integer(500))
        XCTAssertTrue(query.bindings.contains(.text("%O'Brien%")))
        XCTAssertTrue(query.bindings.contains(.text("jwt")))
        XCTAssertTrue(query.bindings.contains(.text("%Terminal%")))
    }

    func testBuild_ordersKeywordBucketsBeforeRecencyAndCapsRequestedLimit() throws {
        let query = SearchCandidateSQLBuilder().build(
            request: request(input: "needle", limit: 501)
        )

        let keywordBucketIndex = try XCTUnwrap(query.sql.range(of: "ORDER BY keyword_bucket ASC")).lowerBound
        let recencyIndex = try XCTUnwrap(query.sql.range(of: "datetime(last_captured_at) DESC")).lowerBound

        XCTAssertLessThan(keywordBucketIndex, recencyIndex)
        XCTAssertEqual(query.bindings.last, .integer(500))
    }

    private func request(
        input: String,
        now: Date = Date(timeIntervalSince1970: 1_750_000_000),
        storageContentType: ClipboardContentType? = nil,
        sourceFilter: HistoryQuery.SourceFilter = .all,
        timeRange: HistoryQuery.TimeRange = .all,
        favoritesOnly: Bool = false,
        limit: Int = 50
    ) -> SearchCandidateRequest {
        SearchCandidateRequest(
            parsedQuery: SearchQueryParser(now: { now }).parse(input),
            storageContentType: storageContentType,
            sourceFilter: sourceFilter,
            timeRange: timeRange,
            favoritesOnly: favoritesOnly,
            limit: limit
        )
    }
}
