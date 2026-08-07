import XCTest

@testable import MacPasteHistory

final class SearchSuggestionProviderTests: XCTestCase {
    private let provider = SearchSuggestionProvider(
        sourceOptions: [
            HistorySourceOption(appName: "Terminal", bundleID: "com.apple.Terminal"),
            HistorySourceOption(appName: "Visual Studio Code", bundleID: "com.microsoft.VSCode")
        ]
    )

    func testSuggestions_offerStructuredPrefixesTypesAndFavoriteValues() {
        XCTAssertEqual(provider.suggestions(for: "a").map(\.replacement), ["app:"])
        XCTAssertEqual(provider.suggestions(for: "ap").map(\.replacement), ["app:"])
        XCTAssertEqual(
            provider.suggestions(for: "type:").map(\.replacement),
            ["type:text", "type:image", "type:json", "type:url", "type:base64", "type:jwt", "type:timestamp", "type:sql", "type:shell"]
        )
        XCTAssertEqual(provider.suggestions(for: "fav:").map(\.replacement), ["fav:true", "fav:false"])
    }

    func testSuggestions_filterSourcesOfferDateValuesAndApplyOnlyTheActiveRange() throws {
        XCTAssertEqual(provider.suggestions(for: "app:v").map(\.replacement), ["app:\"Visual Studio Code\""])
        let sourceSuggestion = try XCTUnwrap(provider.suggestions(for: "app:v").first)
        let parsed = SearchQueryParser().parse(sourceSuggestion.applying(to: "app:v").text)
        XCTAssertEqual(parsed.app, "Visual Studio Code")
        XCTAssertTrue(parsed.terms.isEmpty)
        XCTAssertEqual(
            provider.suggestions(for: "before:").map(\.replacement),
            ["before:1d", "before:7d", "before:30d", "before:YYYY-MM-DD"]
        )

        let suggestion = try XCTUnwrap(provider.suggestions(for: "docker ap").first)
        let accepted = suggestion.applying(to: "docker ap")
        XCTAssertEqual(accepted.text, "docker app:")
        XCTAssertEqual(accepted.cursorOffset, 11)
    }

    func testSuggestions_sortSourcesCaseInsensitivelyAndLimitVisibleResults() {
        let manySources = (0..<12).map {
            HistorySourceOption(appName: "App \(12 - $0)", bundleID: "com.example.\($0)")
        }
        let limitedProvider = SearchSuggestionProvider(sourceOptions: manySources)

        let suggestions = limitedProvider.suggestions(for: "app:")

        XCTAssertEqual(suggestions.count, 10)
        XCTAssertEqual(suggestions.first?.replacement, "app:\"App 1\"")
    }
}
