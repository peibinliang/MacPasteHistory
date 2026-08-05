import XCTest
@testable import MacPasteHistory
final class JWTContentActionTests: XCTestCase {
    func testInspectsUnsignedJWTWithoutSignatureVerification() throws {
        let result = try JWTContentAction().execute(input: "eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.")
        XCTAssertEqual(result.notices.first?.messageKey, "content-action.jwt.signature-not-verified")
        XCTAssertEqual(result.copyVariants.count, 3)
    }
}
