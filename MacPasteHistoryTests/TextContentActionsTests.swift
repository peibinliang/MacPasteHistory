import XCTest
@testable import MacPasteHistory

final class TextContentActionsTests: XCTestCase {
    func testTextTransformationsHaveExactWhitespaceSemantics() throws {
        XCTAssertEqual(try TextContentAction(kind: .trim).execute(input: " \n a \n ").output, "a")
        XCTAssertEqual(try TextContentAction(kind: .removeEmptyLines).execute(input: "a\n \n b").output, "a\n b")
        XCTAssertEqual(try TextContentAction(kind: .deduplicateLines).execute(input: "a\nb\na").output, "a\nb")
        XCTAssertEqual(try TextContentAction(kind: .singleLine).execute(input: "a\n  b\t c").output, "a b c")
        XCTAssertEqual(try TextContentAction(kind: .markdownCodeBlock).execute(input: "a").output, "```\na\n```")
    }
}
