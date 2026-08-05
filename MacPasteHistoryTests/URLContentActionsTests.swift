import XCTest
@testable import MacPasteHistory
final class URLContentActionsTests: XCTestCase {
    func testURLActions() throws {
        XCTAssertEqual(try URLContentAction(kind: .extractHost).execute(input: "https://example.com/x").output, "example.com")
        XCTAssertEqual(try URLContentAction(kind: .parseQuery).execute(input: "https://x.test/?b=2&a=1&a=3").output, "a = 1\na = 3\nb = 2")
    }
}
