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
