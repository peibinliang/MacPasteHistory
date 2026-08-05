import XCTest
@testable import MacPasteHistory
final class ContentSyntaxHighlighterTests: XCTestCase { func testFindsJSONKeys() { XCTAssertEqual(ContentSyntaxHighlighter().tokens(for: "{\"name\":1}", syntax: .json).count, 1) } }
