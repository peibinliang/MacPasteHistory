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

    func testAppVersionInfo_shouldSatisfyInjectableVersionProviderContract() {
        let info = AppVersionInfo(infoDictionary: [
            "CFBundleDisplayName": "Test App",
            "CFBundleShortVersionString": "9.8.7",
            "CFBundleVersion": "654"
        ])

        func versionFields(from provider: any AppVersionProviding) -> [String] {
            [provider.displayName, provider.shortVersion, provider.buildNumber]
        }

        XCTAssertEqual(versionFields(from: info), ["Test App", "9.8.7", "654"])
    }
}
