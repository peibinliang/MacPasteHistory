import XCTest
@testable import MacPasteHistory

final class LanguageManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDownWithError() throws {
        UserDefaults().removePersistentDomain(forName: suiteName)
        suiteName = nil
        defaults = nil
        try super.tearDownWithError()
    }

    func testCurrentLanguage_whenNoPreferenceSet_shouldReturnSystemDefault() {
        let manager = LanguageManager(defaults: defaults)
        XCTAssertEqual(manager.currentLanguage, .system)
    }

    func testSetLanguage_whenEnglish_shouldStorePreferenceAndOverrideAppleLanguages() {
        let manager = LanguageManager(defaults: defaults)

        manager.setLanguage(.en)

        XCTAssertEqual(manager.currentLanguage, .en)
        XCTAssertEqual(defaults.array(forKey: "AppleLanguages") as? [String], ["en"])
    }

    func testSetLanguage_whenSimplifiedChinese_shouldStorePreferenceAndOverrideAppleLanguages() {
        let manager = LanguageManager(defaults: defaults)

        manager.setLanguage(.zhHans)

        XCTAssertEqual(manager.currentLanguage, .zhHans)
        XCTAssertEqual(defaults.array(forKey: "AppleLanguages") as? [String], ["zh-Hans"])
    }

    func testSetLanguage_whenTraditionalChinese_shouldStorePreferenceAndOverrideAppleLanguages() {
        let manager = LanguageManager(defaults: defaults)

        manager.setLanguage(.zhHant)

        XCTAssertEqual(manager.currentLanguage, .zhHant)
        XCTAssertEqual(defaults.array(forKey: "AppleLanguages") as? [String], ["zh-Hant"])
    }

    func testSetLanguage_whenSystem_shouldClearAppleLanguagesOverride() {
        let manager = LanguageManager(defaults: defaults)
        manager.setLanguage(.en)
        let persistentAfterSet = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertNotNil(persistentAfterSet["AppleLanguages"])

        manager.setLanguage(.system)

        XCTAssertEqual(manager.currentLanguage, .system)
        let persistentAfterClear = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertNil(persistentAfterClear["AppleLanguages"])
    }

    func testApplyCurrentLanguage_whenPreferenceExists_shouldApplyAppleLanguagesOverride() {
        defaults.set(AppLanguage.en.rawValue, forKey: LanguageManager.preferredLanguageKey)
        let manager = LanguageManager(defaults: defaults)

        manager.applyCurrentLanguage()

        XCTAssertEqual(defaults.array(forKey: "AppleLanguages") as? [String], ["en"])
    }

    func testAppLanguage_allCases_shouldContainAllFourOptions() {
        XCTAssertEqual(AppLanguage.allCases.count, 4)
        XCTAssertTrue(AppLanguage.allCases.contains(.system))
        XCTAssertTrue(AppLanguage.allCases.contains(.en))
        XCTAssertTrue(AppLanguage.allCases.contains(.zhHans))
        XCTAssertTrue(AppLanguage.allCases.contains(.zhHant))
    }

    func testAppLanguage_languageCode_whenSystem_shouldReturnNil() {
        XCTAssertNil(AppLanguage.system.languageCode)
    }

    func testAppLanguage_languageCode_whenSpecificLanguage_shouldReturnCode() {
        XCTAssertEqual(AppLanguage.en.languageCode, "en")
        XCTAssertEqual(AppLanguage.zhHans.languageCode, "zh-Hans")
        XCTAssertEqual(AppLanguage.zhHant.languageCode, "zh-Hant")
    }
}
