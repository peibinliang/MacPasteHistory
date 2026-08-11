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

    func testDetect_whenCredentialAssignmentMatches_shouldReturnSafeStructuredResult() {
        let result = SensitiveContentDetector.detect("password = TEST-PASSWORD-ONLY")

        XCTAssertEqual(result.category, .credential)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.reason, .credentialAssignment)
        XCTAssertTrue(result.shouldBlockPersistence)
        XCTAssertFalse(result.reason.rawValue.contains("TEST-PASSWORD-ONLY"))
    }

    func testDetect_whenValidatedCardMatches_shouldReturnCardResult() {
        let result = SensitiveContentDetector.detect("4111111111111111")

        XCTAssertEqual(result.category, .bankCard)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.reason, .validatedCardChecksum)
    }

    func testDetect_whenValidatedIdentityMatches_shouldReturnIdentityResult() {
        let result = SensitiveContentDetector.detect("110101200001010010")

        XCTAssertEqual(result.category, .identity)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.reason, .validatedIdentityChecksum)
    }

    func testDetect_whenAuthorizationHeaderMatches_shouldReturnCredentialResult() {
        let result = SensitiveContentDetector.detect(
            "Authorization: Bearer TESTTOKEN0123456789ABCDEF0123456789"
        )

        XCTAssertEqual(result.category, .credential)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.reason, .authorizationHeader)
    }

    func testDetect_whenContextualSecretMatches_shouldReturnSecretResult() {
        let result = SensitiveContentDetector.detect("client_secret = TEST-CLIENT-SECRET")

        XCTAssertEqual(result.category, .secret)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.reason, .contextualSecret)
    }

    func testDetect_whenNoRuleMatches_shouldReturnNonSensitiveResult() {
        let result = SensitiveContentDetector.detect("release commit 0123456789abcdef0123456789abcdef01234567")

        XCTAssertEqual(result.category, .none)
        XCTAssertEqual(result.confidence, .none)
        XCTAssertEqual(result.reason, .noMatch)
        XCTAssertFalse(result.shouldBlockPersistence)
    }

    func testResult_whenConfidenceIsNotHigh_shouldRemainRecordable() {
        let result = SensitiveDetectionResult(
            category: .userRule,
            confidence: .medium,
            reason: .userRuleMatch
        )

        XCTAssertFalse(result.shouldBlockPersistence)
    }

    func testDetector_whenAdditionalUserRuleMatches_shouldPreserveConfiguredConfidence() throws {
        let userRule = try UserSensitiveContentRule(
            pattern: #"internal-project-[0-9]{4}"#,
            confidence: .medium
        )
        let detector = SensitiveContentDetector(additionalRules: [userRule])

        let result = detector.result(for: "internal-project-2048")

        XCTAssertEqual(result.category, .userRule)
        XCTAssertEqual(result.confidence, .medium)
        XCTAssertEqual(result.reason, .userRuleMatch)
        XCTAssertFalse(result.shouldBlockPersistence)
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
