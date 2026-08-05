import XCTest

@testable import MacPasteHistory

final class ContentClassifierTests: XCTestCase {
    private let classifier = ContentClassifier()
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    func testFastClassifier_detectsStructuredContentInPriorityOrder() {
        XCTAssertEqual(classifier.classifyFast("eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.signature", at: date).type, .jwt)
        XCTAssertEqual(classifier.classifyFast("{\"value\": [1, 2]}", at: date).type, .json)
        XCTAssertEqual(classifier.classifyFast("https://example.com/path", at: date).type, .url)
        XCTAssertEqual(classifier.classifyFast("1700000000", at: date).type, .timestamp)
        XCTAssertEqual(classifier.classifyFast("SGVsbG8gd29ybGQ=", at: date).type, .base64)
    }

    func testFastClassifier_keepsAmbiguousValuesAsPlainText() {
        XCTAssertEqual(classifier.classifyFast("abc", at: date).type, .plainText)
        XCTAssertEqual(classifier.classifyFast("example.com", at: date).type, .plainText)
        XCTAssertEqual(classifier.classifyFast("a.b.c", at: date).type, .plainText)
        XCTAssertEqual(classifier.classifyFast("9999999999", at: date).type, .plainText)
    }

    func testCompleteClassifier_detectsSQLAndShellOnlyWhenSignalsAreStrong() {
        XCTAssertEqual(classifier.classifyComplete("SELECT id FROM users WHERE active = 1", at: date).type, .sql)
        XCTAssertEqual(classifier.classifyComplete("UPDATE users SET active = 1", at: date).type, .sql)
        XCTAssertEqual(classifier.classifyComplete("git log --oneline | head -5", at: date).type, .shell)
        XCTAssertEqual(classifier.classifyComplete("SELECT", at: date).type, .plainText)
    }
}
