import XCTest
@testable import MacPasteHistory

final class SensitiveContentDetectorTests: XCTestCase {
    func testIsSensitive_whenHighConfidenceSecretIsPresent_shouldReturnTrue() {
        let samples = [
            "password = TEST-PASSWORD-ONLY",
            "api_key: TEST_API_KEY_0123456789",
            "Authorization: Bearer TESTTOKEN0123456789ABCDEF0123456789",
            "4111111111111111", // Luhn-valid test card number.
            "110101200001010010" // Synthetic ID-shaped value with a valid date and checksum.
        ]

        for sample in samples {
            XCTAssertTrue(
                SensitiveContentDetector.isSensitive(sample),
                "Expected high-confidence test sample to be sensitive"
            )
        }
    }

    func testIsSensitive_whenIdentifierOrInvalidCandidateIsPresent_shouldReturnFalse() {
        let samples = [
            "0123456789abcdef0123456789abcdef01234567", // Git SHA-1.
            "d41d8cd98f00b204e9800998ecf8427e", // MD5.
            "550e8400-e29b-41d4-a716-446655440000", // UUID.
            "trace_id=4bf92f3577b34da6a3ce929d0e0e4736",
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN",
            "4111111111111112", // Invalid Luhn checksum.
            "110101200013010010" // Impossible month.
        ]

        for sample in samples {
            XCTAssertFalse(
                SensitiveContentDetector.isSensitive(sample),
                "Expected developer identifier or invalid test candidate to remain recordable"
            )
        }
    }
}
