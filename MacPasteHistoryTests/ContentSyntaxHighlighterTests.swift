import XCTest
@testable import MacPasteHistory
final class ContentSyntaxHighlighterTests: XCTestCase {
    func testHighlightsJSONAndJWTScalarKinds() {
        let text = "{\"name\":\"粘易\",\"count\":1,\"enabled\":true,\"missing\":null}"
        let kinds = Set(ContentSyntaxHighlighter().tokens(for: text, syntax: .json).map(\.kind))

        XCTAssertTrue(["key", "string", "number", "boolean", "null"].allSatisfy(kinds.contains))
        XCTAssertEqual(Set(ContentSyntaxHighlighter().tokens(for: text, syntax: .jwt).map(\.kind)), kinds)
    }

    func testHighlightsSQLKeywordsStringsNumbersAndComments() {
        let text = "SELECT 'value', 42 FROM t -- comment\nWHERE id = 1 /* block */"
        let kinds = Set(ContentSyntaxHighlighter().tokens(for: text, syntax: .sql).map(\.kind))

        XCTAssertTrue(["keyword", "string", "number", "comment"].allSatisfy(kinds.contains))
    }
}
