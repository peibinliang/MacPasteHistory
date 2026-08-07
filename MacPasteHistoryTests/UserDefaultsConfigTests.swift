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
}
