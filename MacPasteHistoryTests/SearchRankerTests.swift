import XCTest

@testable import MacPasteHistory

final class SearchRankerTests: XCTestCase {
    func testRank_ordersTextMatchesByExactPrefixWholeWordSubstringThenFuzzy() {
        let ranker = SearchRanker(now: { Date(timeIntervalSince1970: 1_750_000_000) })
        let items = [
            item(id: 1, text: "alpha"),
            item(id: 2, text: "alphabet"),
            item(id: 3, text: "an alpha value"),
            item(id: 4, text: "metaalpha"),
            item(id: 5, text: "alphi")
        ]

        let results = ranker.rank(items: items, terms: ["alpha"])

        XCTAssertEqual(results.map(\.id), [1, 2, 3, 4, 5])
    }

    func testRank_doesNotIncludeUnmatchedFavoritesOrHighUsageRecords() {
        let ranker = SearchRanker()
        let unmatchedFavorite = item(
            id: 1,
            text: "unrelated record",
            isFavorite: true,
            pasteCount: 10_000,
            reuseCopyCount: 10_000
        )
        let matching = item(id: 2, text: "needle value")

        let results = ranker.rank(items: [unmatchedFavorite, matching], terms: ["needle"])

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    func testMatcher_boundsFuzzyMatchingToLeadingNormalizedTokens() {
        let matcher = SearchTextMatcher()
        let beyondBound = item(id: 1, text: String(repeating: "x", count: 4_097) + " alphi")
        let allowed = item(id: 2, text: "prefix alphi")

        XCTAssertNil(matcher.match(term: "alpha", in: beyondBound))
        XCTAssertEqual(matcher.match(term: "alpha", in: allowed)?.kind, .fuzzy)
    }

    func testRank_appliesBoundedUsageAndRecencyScoresAfterTextMatch() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let ranker = SearchRanker(now: { now })
        let recent = item(id: 1, text: "needle", lastCapturedAt: now, pasteCount: 64)
        let old = item(id: 2, text: "needle", lastCapturedAt: now.addingTimeInterval(-7 * 86_400))

        let results = ranker.rank(items: [old, recent], terms: ["needle"])

        XCTAssertEqual(results.map(\.id), [recent.id, old.id])
        XCTAssertGreaterThan(results[0].score, results[1].score)
    }

    private func item(
        id: Int64,
        text: String,
        isFavorite: Bool = false,
        lastCapturedAt: Date? = Date(timeIntervalSince1970: 1_750_000_000),
        pasteCount: Int = 0,
        reuseCopyCount: Int = 0
    ) -> ClipboardHistoryItem {
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
            isFavorite: isFavorite,
            isSensitive: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            searchableText: text,
            lastCapturedAt: lastCapturedAt,
            reuseCopyCount: reuseCopyCount,
            pasteCount: pasteCount
        )
    }
}
