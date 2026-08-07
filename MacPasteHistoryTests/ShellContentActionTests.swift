import XCTest
@testable import MacPasteHistory
final class ShellContentActionTests: XCTestCase {
    func testQuoteArgument() throws {
        let action = ShellContentAction()
        XCTAssertEqual(try action.execute(input: "abc").output, "'abc'")
        XCTAssertEqual(try action.execute(input: "it's").output, "'it'\\''s'")
        XCTAssertEqual(try action.execute(input: "").output, "''")
    }
}
