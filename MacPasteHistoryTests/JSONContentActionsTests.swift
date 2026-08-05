import XCTest
@testable import MacPasteHistory
final class JSONContentActionsTests: XCTestCase {
    func testFormatMinifyAndEscape() throws {
        XCTAssertEqual(try JSONContentAction(kind: .minify).execute(input: "{ \"a\" : 1 }").output, "{\"a\":1}")
        XCTAssertTrue(try JSONContentAction(kind: .format).execute(input: "{\"a\":1}").output.contains("\n"))
        XCTAssertEqual(try JSONContentAction(kind: .unescape).execute(input: "\"a\\nb\"").output, "a\nb")
    }
}
