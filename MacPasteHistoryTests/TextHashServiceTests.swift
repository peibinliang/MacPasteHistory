import XCTest
@testable import MacPasteHistory

final class TextHashServiceTests: XCTestCase {
    func testHash_whenTextHasDifferentLineEndings_shouldReturnSameHash() {
        let service = TextHashService()

        let firstHash = service.hash(for: "hello\r\nworld")
        let secondHash = service.hash(for: "hello\nworld")

        XCTAssertEqual(firstHash, secondHash)
    }

    func testHash_whenTextDiffers_shouldReturnDifferentHash() {
        let service = TextHashService()

        let firstHash = service.hash(for: "first value")
        let secondHash = service.hash(for: "second value")

        XCTAssertNotEqual(firstHash, secondHash)
    }
}
