import XCTest
@testable import MacPasteHistory

final class UserDefaultsConfigTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MacPasteHistoryTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testTotalStorageCapInBytes_shouldPersistConfiguredValue() {
        var config = UserDefaultsConfig(defaults: defaults)

        config.totalStorageCapInBytes = 500 * 1024 * 1024

        let reloadedConfig = UserDefaultsConfig(defaults: defaults)
        XCTAssertEqual(reloadedConfig.totalStorageCapInBytes, 500 * 1024 * 1024)
    }

    func testTotalStorageCapInBytes_whenUnset_shouldUseDefaultValue() {
        let config = UserDefaultsConfig(defaults: defaults)

        XCTAssertEqual(config.totalStorageCapInBytes, DefaultSettings.totalStorageCapInBytes)
    }

    func testMaxImageSizeInBytes_whenPersistedValueIsInvalid_shouldUseDefaultValue() {
        defaults.set(0, forKey: UserDefaultsConfig.Key.maxImageSizeInBytes.rawValue)
        let config = UserDefaultsConfig(defaults: defaults)

        XCTAssertEqual(config.maxImageSizeInBytes, DefaultSettings.maxImageSizeInBytes)
    }

    func testRecordingPaused_shouldPersistConfiguredValue() {
        var config = UserDefaultsConfig(defaults: defaults)

        config.recordingPaused = true

        XCTAssertTrue(UserDefaultsConfig(defaults: defaults).recordingPaused)
    }

    func testFilterSensitiveContent_whenUnset_shouldDefaultToEnabled() {
        XCTAssertTrue(UserDefaultsConfig(defaults: defaults).filterSensitiveContent)
    }

    func testSensitiveContentPreferences_shouldPersistDisabledAndAcknowledgedValues() {
        var config = UserDefaultsConfig(defaults: defaults)
        config.filterSensitiveContent = false
        config.hasAcknowledgedSensitiveContentRisk = true

        let reloaded = UserDefaultsConfig(defaults: defaults)
        XCTAssertFalse(reloaded.filterSensitiveContent)
        XCTAssertTrue(reloaded.hasAcknowledgedSensitiveContentRisk)
    }

    func testBlockedApps_shouldPersistStructuredEntries() {
        var config = UserDefaultsConfig(defaults: defaults)
        let entry = BlockedAppEntry(bundleID: "com.apple.Safari", displayName: "Safari")

        config.blockedApps = [entry]

        XCTAssertEqual(UserDefaultsConfig(defaults: defaults).blockedApps, [entry])
    }

    func testShortcutConfiguration_whenUnset_shouldUseDefaultShortcut() {
        let config = UserDefaultsConfig(defaults: defaults)

        XCTAssertEqual(config.shortcutConfiguration, .default)
    }

    func testShortcutConfiguration_shouldPersistConfiguredShortcut() {
        var config = UserDefaultsConfig(defaults: defaults)
        let shortcut = ShortcutConfiguration(keyCode: 8, modifiers: 1_280)

        config.shortcutConfiguration = shortcut

        XCTAssertEqual(UserDefaultsConfig(defaults: defaults).shortcutConfiguration, shortcut)
    }

    func testAppAppearance_whenUnsetOrInvalid_shouldFollowSystem() {
        let config = UserDefaultsConfig(defaults: defaults)

        XCTAssertEqual(config.appAppearance, .system)

        config.setString("unsupported", forKey: .appAppearance)

        XCTAssertEqual(config.appAppearance, .system)
    }

    func testAppAppearance_shouldPersistLightAndDarkPreferences() {
        var config = UserDefaultsConfig(defaults: defaults)

        config.appAppearance = .light
        XCTAssertEqual(UserDefaultsConfig(defaults: defaults).appAppearance, .light)

        config.appAppearance = .dark
        XCTAssertEqual(UserDefaultsConfig(defaults: defaults).appAppearance, .dark)
    }

    func testAppAppearance_shouldExposeStableValuesAndLocalizationKeys() {
        XCTAssertEqual(AppAppearance.allCases.map(\.id), ["system", "light", "dark"])
        XCTAssertEqual(AppAppearance.allCases.map(\.titleKey), ["Follow System", "Light", "Dark"])
    }

    func testAutomaticPasteEnabled_whenUnset_shouldDefaultToFalse() {
        let config = UserDefaultsConfig(defaults: defaults)

        XCTAssertFalse(config.automaticPasteEnabled)
    }

    func testAutomaticPasteEnabled_shouldPersistExplicitChoice() {
        var config = UserDefaultsConfig(defaults: defaults)

        config.automaticPasteEnabled = true

        XCTAssertTrue(UserDefaultsConfig(defaults: defaults).automaticPasteEnabled)
    }

    func testAISettings_whenUnset_shouldUseSafeDefaults() {
        let config = UserDefaultsConfig(defaults: defaults)

        XCTAssertEqual(config.aiModelIdentifier, DefaultSettings.aiModelIdentifier)
        XCTAssertFalse(config.hasAcknowledgedAIRemoteProcessing)
    }

    func testAISettings_shouldPersistValidatedModelAndAcknowledgment() {
        var config = UserDefaultsConfig(defaults: defaults)

        config.aiModelIdentifier = "deepseek-v4-pro"
        config.hasAcknowledgedAIRemoteProcessing = true

        let reloaded = UserDefaultsConfig(defaults: defaults)
        XCTAssertEqual(reloaded.aiModelIdentifier, "deepseek-v4-pro")
        XCTAssertTrue(reloaded.hasAcknowledgedAIRemoteProcessing)
    }

    func testAIModelIdentifier_whenPersistedValueIsBlank_shouldUseDefault() {
        var config = UserDefaultsConfig(defaults: defaults)

        config.aiModelIdentifier = "  \n"

        XCTAssertEqual(config.aiModelIdentifier, DefaultSettings.aiModelIdentifier)
    }

    func testAITranslationTarget_shouldDefaultPersistAndRejectUnknownValues() {
        var config = UserDefaultsConfig(defaults: defaults)

        XCTAssertEqual(config.aiTranslationTarget, .simplifiedChinese)

        config.aiTranslationTarget = .english
        XCTAssertEqual(UserDefaultsConfig(defaults: defaults).aiTranslationTarget, .english)

        defaults.set("unknown-language", forKey: UserDefaultsConfig.Key.aiTranslationTarget.rawValue)
        XCTAssertEqual(UserDefaultsConfig(defaults: defaults).aiTranslationTarget, .simplifiedChinese)
    }
}
