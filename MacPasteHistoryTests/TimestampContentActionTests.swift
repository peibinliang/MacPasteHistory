import XCTest
@testable import MacPasteHistory
final class TimestampContentActionTests: XCTestCase { func testSecondsProduceFiveVariants() throws { XCTAssertEqual(try TimestampContentAction().execute(input: "1700000000").copyVariants.count, 5) } }
