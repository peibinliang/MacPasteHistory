import XCTest
@testable import MacPasteHistory

final class AppVersionInfoTests: XCTestCase {
    func testAppVersionInfo_shouldReadDisplayVersionAndBuildFromDictionary() {
        let info = AppVersionInfo(infoDictionary: [
            "CFBundleDisplayName": "粘易",
            "CFBundleShortVersionString": "1.0.1",
            "CFBundleVersion": "2"
        ])

        XCTAssertEqual(info.displayName, "粘易")
        XCTAssertEqual(info.shortVersion, "1.0.1")
        XCTAssertEqual(info.buildNumber, "2")
    }

    func testAppVersionInfo_whenBundleValuesAreMissing_shouldUseStableFallbacks() {
        let info = AppVersionInfo(infoDictionary: [:])

        XCTAssertEqual(info.displayName, AppBrand.displayName)
        XCTAssertEqual(info.shortVersion, "—")
        XCTAssertEqual(info.buildNumber, "—")
    }
}
