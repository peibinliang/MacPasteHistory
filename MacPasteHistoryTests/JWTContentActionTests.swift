import XCTest
@testable import MacPasteHistory
final class JWTContentActionTests: XCTestCase {
    func testInspectsClaimsFormatsJSONAndReportsExpiration() throws {
        let token = makeToken(
            header: ["alg": "none", "typ": "JWT"],
            payload: ["iss": "issuer", "sub": "user-1", "aud": "粘易", "iat": 1_600_000_000, "nbf": 1_600_000_100, "exp": 1_700_000_000]
        )

        let result = try JWTContentAction().execute(input: token)

        XCTAssertTrue(result.output.contains("\"alg\" : \"none\""))
        XCTAssertTrue(result.output.contains("iss = issuer"))
        XCTAssertTrue(result.output.contains("aud = 粘易"))
        XCTAssertTrue(result.output.contains("exp.iso8601 = "))
        XCTAssertEqual(result.notices.map(\.messageKey), [
            "content-action.jwt.signature-not-verified",
            "content-action.jwt.expired"
        ])
        XCTAssertEqual(result.copyVariants.count, 3)
        XCTAssertTrue(result.copyVariants.first { $0.id == "header" }?.value.contains("\n") == true)
        XCTAssertEqual(result.copyVariants.first { $0.id == "summary" }?.value, result.output)
    }

    func testReportsMissingAndFutureExpirationStates() throws {
        let noExpiry = try JWTContentAction().execute(input: makeToken(header: ["alg": "none"], payload: ["sub": "1"]))
        let future = try JWTContentAction().execute(input: makeToken(header: ["alg": "none"], payload: ["exp": 4_102_444_800]))

        XCTAssertEqual(noExpiry.notices.last?.messageKey, "content-action.jwt.no-expiration")
        XCTAssertEqual(future.notices.last?.messageKey, "content-action.jwt.not-expired")
    }

    private func makeToken(header: [String: Any], payload: [String: Any]) -> String {
        [header, payload].map { object in
            let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }.joined(separator: ".") + "."
    }
}
