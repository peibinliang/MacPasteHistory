import XCTest
@testable import MacPasteHistory
final class TimestampContentActionTests: XCTestCase {
    func testSecondsMillisecondsISOAndLocalDateProduceExactUnixVariants() throws {
        let action = TimestampContentAction()

        XCTAssertEqual(variants(try action.execute(input: "1700000000"))["milliseconds"], "1700000000000")
        XCTAssertEqual(variants(try action.execute(input: "1700000000000"))["seconds"], "1700000000")
        XCTAssertEqual(variants(try action.execute(input: "2023-11-14T22:13:20Z"))["seconds"], "1700000000")
        XCTAssertNoThrow(try action.execute(input: "2023-11-14 22:13:20"))
        XCTAssertEqual(try action.execute(input: "1700000000").copyVariants.count, 5)
    }

    func testInvalidTimestampExplainsAcceptedFormats() {
        XCTAssertThrowsError(try ContentActionExecutor().execute(id: ContentActionID(rawValue: "timestamp.convert"), input: "yesterday")) { error in
            XCTAssertEqual(error as? ContentActionError, .invalidInput(messageKey: "content-action.timestamp.invalid"))
        }
    }

    private func variants(_ result: ContentActionResult) -> [String: String] {
        Dictionary(uniqueKeysWithValues: result.copyVariants.map { ($0.id, $0.value) })
    }
}
