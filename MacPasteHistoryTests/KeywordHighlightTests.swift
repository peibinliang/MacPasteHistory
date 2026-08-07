import XCTest

@testable import MacPasteHistory

@MainActor
final class KeywordHighlightTests: XCTestCase {
    func testHighlightedText_preservesTextAndHighlightsCaseInsensitiveMatches() {
        let attributed = KeywordHighlightedText(text: "JSON json", terms: ["json"]).attributedText

        XCTAssertEqual(String(attributed.characters), "JSON json")
        XCTAssertEqual(attributed.runs.filter { $0.backgroundColor != nil }.count, 2)
    }

    func testHighlightedText_handlesOverlappingTermsByPrioritizingLongerTerm() {
        let attributed = KeywordHighlightedText(text: "json", terms: ["son", "json"]).attributedText

        XCTAssertEqual(attributed.runs.filter { $0.backgroundColor != nil }.count, 1)
    }
}
