import XCTest
@testable import MacPasteHistory
final class Base64ContentActionsTests: XCTestCase {
    func testEncodeAndURLSafeDecode() throws {
        XCTAssertEqual(try Base64ContentAction(kind: .encode).execute(input: "Hello").output, "SGVsbG8=")
        XCTAssertEqual(try Base64ContentAction(kind: .decodeURLSafe).execute(input: "SGVsbG8").output, "Hello")
    }
}
