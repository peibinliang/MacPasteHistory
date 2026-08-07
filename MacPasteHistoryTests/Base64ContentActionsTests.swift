import XCTest
@testable import MacPasteHistory
final class Base64ContentActionsTests: XCTestCase {
    func testExecutorEncodesUnicodeTextAsUTF8Base64() throws {
        let result = try ContentActionExecutor().execute(
            id: ContentActionID(rawValue: "base64.encode"),
            input: "中文"
        )

        XCTAssertEqual(result.output, "5Lit5paH")
    }

    func testValidateAcceptsBase64ForNonUTF8BinaryData() throws {
        let result = try ContentActionExecutor().execute(
            id: ContentActionID(rawValue: "base64.validate"),
            input: "/9j/"
        )

        XCTAssertEqual(result.output, "/9j/")
        XCTAssertEqual(result.notices, [ContentActionNotice(messageKey: "content-action.base64.valid")])
    }

    func testEncodeAndURLSafeDecode() throws {
        XCTAssertEqual(try Base64ContentAction(kind: .encode).execute(input: "Hello").output, "SGVsbG8=")
        XCTAssertEqual(try Base64ContentAction(kind: .decode).execute(input: "5Lit5paH").output, "中文")
        XCTAssertEqual(try Base64ContentAction(kind: .decode).execute(input: "SGVsbG8").output, "Hello")
        XCTAssertEqual(try Base64ContentAction(kind: .decodeURLSafe).execute(input: "SGVsbG8").output, "Hello")
    }

    func testDecodeRejectsInvalidNonUTF8AndMostlyNonPrintableResults() {
        XCTAssertThrowsError(try ContentActionExecutor().execute(id: ContentActionID(rawValue: "base64.decode"), input: "not base64"))
        XCTAssertThrowsError(try ContentActionExecutor().execute(id: ContentActionID(rawValue: "base64.decode"), input: "/9j/"))
        XCTAssertThrowsError(try ContentActionExecutor().execute(id: ContentActionID(rawValue: "base64.decode"), input: "AAEC"))
    }
}
