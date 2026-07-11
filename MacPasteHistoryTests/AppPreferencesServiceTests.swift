import AppKit
import XCTest
@testable import MacPasteHistory

@MainActor
final class AppPreferencesServiceTests: XCTestCase {
    func testSetDockIconVisible_whenEnabled_shouldPersistAndApplyRegularPolicy() {
        let defaults = UserDefaults(suiteName: "AppPreferencesServiceTests.\(UUID().uuidString)")!
        var appliedPolicy: NSApplication.ActivationPolicy?
        let config = UserDefaultsConfig(defaults: defaults)
        let service = AppPreferencesService(config: config) { policy in
            appliedPolicy = policy
            return true
        }

        let result = service.setDockIconVisible(true)

        XCTAssertEqual(result, .applied)
        XCTAssertTrue(UserDefaultsConfig(defaults: defaults).showDockIcon)
        XCTAssertEqual(appliedPolicy, .regular)
    }

    func testApplyDockIconPreference_whenDisabled_shouldApplyAccessoryPolicy() {
        let defaults = UserDefaults(suiteName: "AppPreferencesServiceTests.\(UUID().uuidString)")!
        var config = UserDefaultsConfig(defaults: defaults)
        config.showDockIcon = false
        var appliedPolicy: NSApplication.ActivationPolicy?
        let service = AppPreferencesService(config: config) { policy in
            appliedPolicy = policy
            return true
        }

        let result = service.applyDockIconPreference()

        XCTAssertEqual(result, .applied)
        XCTAssertEqual(appliedPolicy, .accessory)
    }

    func testSetDockIconVisible_whenPolicyFails_shouldReturnRestartRequiredAndKeepPreference() {
        let defaults = UserDefaults(suiteName: "AppPreferencesServiceTests.\(UUID().uuidString)")!
        let config = UserDefaultsConfig(defaults: defaults)
        let service = AppPreferencesService(config: config) { _ in false }

        let result = service.setDockIconVisible(true)

        XCTAssertEqual(result, .restartRequired)
        XCTAssertTrue(UserDefaultsConfig(defaults: defaults).showDockIcon)
    }
}
