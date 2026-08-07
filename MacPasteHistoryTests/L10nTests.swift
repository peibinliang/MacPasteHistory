import XCTest
@testable import MacPasteHistory

final class L10nTests: XCTestCase {
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

    func testString_whenSimplifiedChinesePreferred_shouldUseSimplifiedChineseBundle() {
        defaults.set(AppLanguage.zhHans.rawValue, forKey: LanguageManager.preferredLanguageKey)

        let value = L10n.string("Clipboard History", defaults: defaults)

        XCTAssertEqual(value, "剪贴板历史")
    }

    func testString_whenSystemPreferred_shouldUseBundleFallback() {
        let value = L10n.string("Clipboard History", defaults: defaults)

        XCTAssertTrue(["Clipboard History", "剪贴板历史", "剪貼板歷史"].contains(value))
    }

    func testString_whenSystemPreferredUsesTraditionalChinesePreference() {
        defaults.set(["zh-Hant-TW"], forKey: "AppleLanguages")

        XCTAssertEqual(L10n.string("Recognize Text", defaults: defaults), "擷取文字")
    }

    func testString_whenKeyIsMissing_shouldReturnKey() {
        defaults.set(AppLanguage.zhHans.rawValue, forKey: LanguageManager.preferredLanguageKey)

        let value = L10n.string("Missing Localization Key", defaults: defaults)

        XCTAssertEqual(value, "Missing Localization Key")
    }
}
