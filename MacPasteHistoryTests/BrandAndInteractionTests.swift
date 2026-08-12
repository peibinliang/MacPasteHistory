import XCTest
import AppKit
@testable import MacPasteHistory

final class BrandAndInteractionTests: XCTestCase {
    func testAppBrand_shouldUseZhanYiAsDisplayName() {
        XCTAssertEqual(AppBrand.displayName, "粘易")
    }

    func testHistoryRowInteraction_whenSingleClicked_shouldPasteImmediately() {
        XCTAssertEqual(HistoryRowInteraction.primaryAction, .paste)
    }

    func testHistoryPanelAppearance_shouldSuppressDefaultKeyboardFocusRing() {
        XCTAssertTrue(HistoryPanelWindow.keyboardFocusEffectDisabled)
    }

    func testPasteActivationPolicy_shouldForcePreviousApplicationToFront() {
        XCTAssertTrue(PasteActivationPolicy.options.contains(.activateIgnoringOtherApps))
    }

    func testPasteTargetPolicy_whenZhanYiIsFrontmost_shouldKeepLastExternalApplication() {
        let targetBundleIdentifier = PasteTargetPolicy.preferredBundleIdentifier(
            frontmostBundleIdentifier: "com.peibin.MacPasteHistory",
            lastExternalBundleIdentifier: "com.apple.TextEdit",
            ownBundleIdentifier: "com.peibin.MacPasteHistory"
        )

        XCTAssertEqual(targetBundleIdentifier, "com.apple.TextEdit")
    }

    func testPasteTargetPolicy_whenExternalApplicationIsFrontmost_shouldPreferIt() {
        let targetBundleIdentifier = PasteTargetPolicy.preferredBundleIdentifier(
            frontmostBundleIdentifier: "com.apple.Safari",
            lastExternalBundleIdentifier: "com.apple.TextEdit",
            ownBundleIdentifier: "com.peibin.MacPasteHistory"
        )

        XCTAssertEqual(targetBundleIdentifier, "com.apple.Safari")
    }

    func testAppLaunchPolicy_whenQAOpenIsRequestedWithIsolatedData_shouldOpenHistory() {
        XCTAssertTrue(AppLaunchPolicy.shouldOpenHistory(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_OPEN_HISTORY_ON_LAUNCH": "1"
        ]))
    }

    func testAppLaunchPolicy_whenIsolationOrExplicitFlagIsMissing_shouldNotOpenHistory() {
        XCTAssertFalse(AppLaunchPolicy.shouldOpenHistory(environment: [
            "MACPASTEHISTORY_OPEN_HISTORY_ON_LAUNCH": "1"
        ]))
        XCTAssertFalse(AppLaunchPolicy.shouldOpenHistory(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa"
        ]))
        XCTAssertFalse(AppLaunchPolicy.shouldOpenHistory(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_OPEN_HISTORY_ON_LAUNCH": "0"
        ]))
    }

    func testAppLaunchPolicy_whenIsolatedQASuiteIsValid_shouldReturnSuiteName() {
        XCTAssertEqual(AppLaunchPolicy.isolatedUserDefaultsSuiteName(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_USER_DEFAULTS_SUITE": "com.peibin.MacPasteHistory.qa.v103-smoke"
        ]), "com.peibin.MacPasteHistory.qa.v103-smoke")
    }

    func testAppLaunchPolicy_whenQASuiteIsUnscopedOrIsolationIsMissing_shouldRejectSuite() {
        XCTAssertNil(AppLaunchPolicy.isolatedUserDefaultsSuiteName(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_USER_DEFAULTS_SUITE": "com.example.unscoped"
        ]))
        XCTAssertNil(AppLaunchPolicy.isolatedUserDefaultsSuiteName(environment: [
            "MACPASTEHISTORY_USER_DEFAULTS_SUITE": "com.peibin.MacPasteHistory.qa.v103-smoke"
        ]))
    }

    func testUserDefaultsConfig_whenQASuiteIsIsolated_shouldWriteOnlyThatSuite() {
        let suiteName = "com.peibin.MacPasteHistory.qa.\(UUID().uuidString)"
        let isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }

        var config = UserDefaultsConfig(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_USER_DEFAULTS_SUITE": suiteName
        ])
        config.recordingPaused = true

        XCTAssertTrue(isolatedDefaults.bool(forKey: UserDefaultsConfig.Key.recordingPaused.rawValue))
    }

    @MainActor
    func testAppDelegateSettingsFactory_whenQASuiteIsolated_shouldKeepLanguageOutOfStandardDefaults() {
        let suiteName = "com.peibin.MacPasteHistory.qa.\(UUID().uuidString)"
        let isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        let standardPreferredLanguage = UserDefaults.standard.object(forKey: LanguageManager.preferredLanguageKey)
        let standardAppleLanguages = UserDefaults.standard.object(forKey: "AppleLanguages")
        defer {
            isolatedDefaults.removePersistentDomain(forName: suiteName)
            restoreStandardDefaultsValue(standardPreferredLanguage, forKey: LanguageManager.preferredLanguageKey)
            restoreStandardDefaultsValue(standardAppleLanguages, forKey: "AppleLanguages")
        }

        let config = UserDefaultsConfig(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_USER_DEFAULTS_SUITE": suiteName
        ])
        let viewModel = AppDelegate().makeSettingsViewModel(config: config)
        viewModel.updateLanguage(.zhHans)

        XCTAssertEqual(isolatedDefaults.string(forKey: LanguageManager.preferredLanguageKey), "zh-Hans")
        XCTAssertEqual(isolatedDefaults.stringArray(forKey: "AppleLanguages"), ["zh-Hans"])
        XCTAssertEqual(UserDefaults.standard.object(forKey: LanguageManager.preferredLanguageKey) as? NSObject,
                       standardPreferredLanguage as? NSObject)
        XCTAssertEqual(UserDefaults.standard.object(forKey: "AppleLanguages") as? NSObject,
                       standardAppleLanguages as? NSObject)
    }

    @MainActor
    func testAppDelegateAggregationPreferences_whenQASuiteIsolated_shouldKeepDateOutOfStandardDefaults() {
        let key = "captureEventAggregation.lastAggregationDate"
        let suiteName = "com.peibin.MacPasteHistory.qa.\(UUID().uuidString)"
        let isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        let standardValue = UserDefaults.standard.object(forKey: key)
        defer {
            isolatedDefaults.removePersistentDomain(forName: suiteName)
            restoreStandardDefaultsValue(standardValue, forKey: key)
        }

        let config = UserDefaultsConfig(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_USER_DEFAULTS_SUITE": suiteName
        ])
        let preferences = AppDelegate().makeCaptureEventAggregationPreferences(config: config)
        let qaDate = Date(timeIntervalSince1970: 1_786_425_600)
        preferences.lastAggregationDate = qaDate

        XCTAssertEqual(isolatedDefaults.object(forKey: key) as? Date, qaDate)
        XCTAssertEqual(UserDefaults.standard.object(forKey: key) as? NSObject, standardValue as? NSObject)
    }

    @MainActor
    func testAppDelegateLoginItemFactory_whenQASuiteIsolated_shouldAvoidSystemRegistration() throws {
        let suiteName = "com.peibin.MacPasteHistory.qa.\(UUID().uuidString)"
        let isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }
        let config = UserDefaultsConfig(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_USER_DEFAULTS_SUITE": suiteName
        ])

        let service = AppDelegate().makeLoginItemService(config: config)
        try service.setLaunchAtLoginEnabled(true)

        XCTAssertFalse(service.usesSystemRegistration)
        XCTAssertTrue(isolatedDefaults.bool(forKey: UserDefaultsConfig.Key.launchAtStartup.rawValue))
    }

    @MainActor
    func testAppDelegateLoginItemFactory_whenProductionDefaultsAreInjected_shouldUseSystemRegistration() {
        let suiteName = "BrandAndInteractionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = AppDelegate().makeLoginItemService(config: UserDefaultsConfig(defaults: defaults))

        XCTAssertTrue(service.usesSystemRegistration)
    }

    @MainActor
    func testAppDelegateShortcutFactory_whenQASuiteIsolated_shouldAvoidGlobalRegistration() {
        let suiteName = "com.peibin.MacPasteHistory.qa.\(UUID().uuidString)"
        let isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }
        let config = UserDefaultsConfig(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_USER_DEFAULTS_SUITE": suiteName
        ])

        let service = AppDelegate().makeSettingsShortcutService(config: config)
        let state = service.register(configuration: ShortcutConfiguration(keyCode: 11, modifiers: 256))

        XCTAssertFalse(service.usesSystemRegistration)
        XCTAssertEqual(state, .registered(ShortcutConfiguration(keyCode: 11, modifiers: 256)))
        XCTAssertEqual(UserDefaultsConfig(defaults: isolatedDefaults).shortcutConfiguration.keyCode, 11)
    }

    @MainActor
    func testAppDelegateRuntimeShortcutFactory_whenQASuiteIsolated_shouldAvoidStartupGlobalRegistration() {
        let service = AppDelegate.makeRuntimeShortcutService(environment: [
            "MACPASTEHISTORY_APP_SUPPORT_DIR": "/tmp/mph-isolated-qa",
            "MACPASTEHISTORY_USER_DEFAULTS_SUITE": "com.peibin.MacPasteHistory.qa.runtime-shortcut"
        ])

        XCTAssertFalse(service.usesSystemRegistration)
    }

    @MainActor
    func testAppDelegateRuntimeShortcutFactory_whenQASuiteIsAbsent_shouldUseStartupGlobalRegistration() {
        XCTAssertTrue(AppDelegate.makeRuntimeShortcutService(environment: [:]).usesSystemRegistration)
    }

    private func restoreStandardDefaultsValue(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @MainActor
    func testAppDelegateSettingsFactory_shouldReuseApplicationShortcutService() {
        let defaults = UserDefaults(suiteName: "BrandAndInteractionTests.\(UUID().uuidString)")!
        let config = UserDefaultsConfig(defaults: defaults)
        let shortcutService = ShortcutService(
            config: config,
            registrationManager: BrandFakeShortcutRegistrationManager()
        )
        let appDelegate = AppDelegate(shortcutService: shortcutService)

        let viewModel = appDelegate.makeSettingsViewModel(config: config)

        XCTAssertTrue(viewModel.shortcutService === shortcutService)
    }

    @MainActor
    func testAppDelegateUpdateFactory_shouldReuseApplicationUpdateService() {
        let appDelegate = AppDelegate()

        let first = appDelegate.makeUpdateService()
        let second = appDelegate.makeUpdateService()

        XCTAssertTrue(first === second)
    }
}

private final class BrandFakeShortcutRegistrationManager: ShortcutRegistrationManaging {
    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        noErr
    }

    func unregister() {}
}
