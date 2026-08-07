import XCTest
@testable import MacPasteHistory
final class SQLContentActionTests: XCTestCase {
    func testCollapsesOnlyWhitespaceOutsideQuotesAndComments() throws {
        let action = SQLContentAction()

        XCTAssertEqual(try action.execute(input: "SELECT  a \n FROM t").output, "SELECT a FROM t")
        XCTAssertEqual(try action.execute(input: "SELECT 'a  b', \"c  d\", `e  f` FROM t").output, "SELECT 'a  b', \"c  d\", `e  f` FROM t")
        XCTAssertEqual(
            try action.execute(input: "SELECT 1  -- keep   this\n  FROM t /* block   comment */  WHERE id = 1").output,
            "SELECT 1 -- keep   this\nFROM t /* block   comment */ WHERE id = 1"
        )
        XCTAssertEqual(try action.execute(input: "SELECT 'it''s  fine'  FROM t").output, "SELECT 'it''s  fine' FROM t")
    }
}
