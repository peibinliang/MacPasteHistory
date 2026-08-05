import XCTest
@testable import MacPasteHistory
final class SQLContentActionTests: XCTestCase { func testCollapsesOrdinaryWhitespace() throws { XCTAssertEqual(try SQLContentAction().execute(input: "SELECT  a \n FROM t").output, "SELECT a FROM t") } }
