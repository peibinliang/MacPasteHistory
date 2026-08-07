import XCTest
@testable import MacPasteHistory
final class JSONContentActionsTests: XCTestCase {
    func testAllJSONActionsProduceExactOutput() throws {
        XCTAssertEqual(try JSONContentAction(kind: .minify).execute(input: "{ \"a\" : 1 }").output, "{\"a\":1}")
        XCTAssertEqual(
            try JSONContentAction(kind: .format).execute(input: "{\"text\":\"中文/路径\",\"nested\":{\"value\":1}}").output,
            "{\n    \"nested\" : {\n        \"value\" : 1\n    },\n    \"text\" : \"中文/路径\"\n}"
        )
        XCTAssertEqual(try JSONContentAction(kind: .escape).execute(input: "a\n\"b\"").output, "a\\n\\\"b\\\"")
        XCTAssertEqual(try JSONContentAction(kind: .unescape).execute(input: "\"a\\nb\"").output, "a\nb")

        let validation = try JSONContentAction(kind: .validate).execute(input: "{\"valid\":true}")
        XCTAssertEqual(validation.notices, [ContentActionNotice(messageKey: "content-action.json.valid")])
    }

    func testInvalidJSONAndInvalidUnescapeAreRejectedByExecutor() {
        XCTAssertThrowsError(try ContentActionExecutor().execute(id: ContentActionID(rawValue: "json.validate"), input: "{bad}"))
        XCTAssertThrowsError(try ContentActionExecutor().execute(id: ContentActionID(rawValue: "json.unescape"), input: "\\x"))
    }

    func testUnescape_acceptsEscapedStringFragmentThroughExecutor() throws {
        let result = try ContentActionExecutor().execute(
            id: ContentActionID(rawValue: "json.unescape"),
            input: "hello\\nworld"
        )

        XCTAssertEqual(result.output, "hello\nworld")
    }
}
