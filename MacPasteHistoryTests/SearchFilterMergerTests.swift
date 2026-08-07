import XCTest

@testable import MacPasteHistory

final class SearchFilterMergerTests: XCTestCase {
    func testMerge_syntaxOverridesEveryMatchingControlDimension() {
        let parsed = ParsedSearchQuery(
            rawInput: "app:Terminal type:json fav:false before:7d after:30d",
            terms: [],
            app: "Terminal",
            type: .json,
            favorite: false,
            before: Date(timeIntervalSince1970: 10),
            after: Date(timeIntervalSince1970: 20),
            tokens: [],
            issues: []
        )
        let controls = SearchUIFilters(
            selectedSourceOption: HistorySourceOption(appName: "Safari", bundleID: "com.apple.Safari"),
            selectedContentType: .image,
            isFavoritesOnly: true,
            selectedTimeRange: .last30Days
        )

        let merged = SearchFilterMerger().merge(parsedQuery: parsed, controls: controls)

        XCTAssertEqual(merged.sourceFilter, HistoryQuery.SourceFilter(appName: "Terminal", bundleID: nil))
        XCTAssertNil(merged.storageContentType)
        XCTAssertFalse(merged.favoritesOnly)
        XCTAssertEqual(merged.favoriteFilter, false)
        XCTAssertEqual(merged.timeRange, .all)
    }

    func testMerge_preservesControlsForDimensionsAbsentFromSyntax() {
        let parsed = ParsedSearchQuery(
            rawInput: "docker",
            terms: ["docker"],
            app: nil,
            type: nil,
            favorite: nil,
            before: nil,
            after: nil,
            tokens: [],
            issues: []
        )
        let source = HistorySourceOption(appName: "Safari", bundleID: "com.apple.Safari")
        let controls = SearchUIFilters(
            selectedSourceOption: source,
            selectedContentType: .image,
            isFavoritesOnly: true,
            selectedTimeRange: .last7Days
        )

        let merged = SearchFilterMerger().merge(parsedQuery: parsed, controls: controls)

        XCTAssertEqual(merged.sourceFilter, source.filter)
        XCTAssertEqual(merged.storageContentType, .image)
        XCTAssertTrue(merged.favoritesOnly)
        XCTAssertEqual(merged.favoriteFilter, true)
        XCTAssertEqual(merged.timeRange, .last7Days)
    }

    func testMerge_mapsSyntaxStorageTypesForTextAndImage() {
        let controls = SearchUIFilters()

        XCTAssertEqual(
            SearchFilterMerger().merge(parsedQuery: parsed(type: .plainText), controls: controls).storageContentType,
            .text
        )
        XCTAssertEqual(
            SearchFilterMerger().merge(parsedQuery: parsed(type: .image), controls: controls).storageContentType,
            .image
        )
    }

    private func parsed(type: DetectedContentType) -> ParsedSearchQuery {
        ParsedSearchQuery(
            rawInput: "",
            terms: [],
            app: nil,
            type: type,
            favorite: nil,
            before: nil,
            after: nil,
            tokens: [],
            issues: []
        )
    }
}
