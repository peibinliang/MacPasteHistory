import XCTest
@testable import MacPasteHistory
final class URLContentActionsTests: XCTestCase {
    func testEncodeQueryValueEncodesReservedCharactersAndUnicode() throws {
        let output = try URLContentAction(kind: .encodeQueryValue)
            .execute(input: "https://example.com/a path?query=中文+value&sort=desc")
            .output

        XCTAssertEqual(output, "https%3A%2F%2Fexample.com%2Fa%20path%3Fquery%3D%E4%B8%AD%E6%96%87%2Bvalue%26sort%3Ddesc")
    }

    func testURLActions() throws {
        XCTAssertEqual(try URLContentAction(kind: .extractHost).execute(input: "https://example.com/x").output, "example.com")
        XCTAssertEqual(try URLContentAction(kind: .parseQuery).execute(input: "https://x.test/?b=2&a=1&a=3").output, "a = 1\na = 3\nb = 2")
    }
}
