import XCTest
@testable import MacPasteHistory

final class TextContentActionsTests: XCTestCase {
    func testTextTransformationsHaveExactWhitespaceSemantics() throws {
        XCTAssertEqual(try TextContentAction(kind: .trim).execute(input: " \n a \n ").output, "a")
        XCTAssertEqual(try TextContentAction(kind: .removeEmptyLines).execute(input: "a\n \n b").output, "a\n b")
        XCTAssertEqual(try TextContentAction(kind: .deduplicateLines).execute(input: "a\nb\na").output, "a\nb")
        XCTAssertEqual(try TextContentAction(kind: .singleLine).execute(input: "a\n  b\t c").output, "a b c")
        XCTAssertEqual(try TextContentAction(kind: .uppercase).execute(input: "Hello 中文").output, "HELLO 中文")
        XCTAssertEqual(try TextContentAction(kind: .lowercase).execute(input: "Hello 中文").output, "hello 中文")
        XCTAssertEqual(try TextContentAction(kind: .markdownCodeBlock).execute(input: "a").output, "```\na\n```")
    }
}
