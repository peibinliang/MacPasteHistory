import Carbon
import XCTest
@testable import MacPasteHistory

final class ShortcutServiceTests: XCTestCase {
    func testRegisterConfiguredShortcut_whenUnset_shouldRegisterDefaultShortcut() {
        let defaults = UserDefaults(suiteName: "ShortcutServiceTests.\(UUID().uuidString)")!
        let manager = FakeShortcutRegistrationManager()
        let service = ShortcutService(config: UserDefaultsConfig(defaults: defaults), registrationManager: manager)

        let state = service.registerConfiguredShortcut()

        XCTAssertEqual(state, .registered(.default))
        XCTAssertEqual(manager.registeredKeyCode, ShortcutConfiguration.default.keyCode)
        XCTAssertEqual(manager.registeredModifiers, ShortcutConfiguration.default.modifiers)
    }

    func testRegisterConfiguration_whenValid_shouldPersistAndRegisterShortcut() {
        let defaults = UserDefaults(suiteName: "ShortcutServiceTests.\(UUID().uuidString)")!
        let config = UserDefaultsConfig(defaults: defaults)
        let manager = FakeShortcutRegistrationManager()
        let service = ShortcutService(config: config, registrationManager: manager)
        let shortcut = ShortcutConfiguration(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey | optionKey))

        let state = service.register(configuration: shortcut)

        XCTAssertEqual(state, .registered(shortcut))
        XCTAssertEqual(UserDefaultsConfig(defaults: defaults).shortcutConfiguration, shortcut)
    }

    func testRegisterConfiguration_whenInvalid_shouldNotPersistShortcut() {
        let defaults = UserDefaults(suiteName: "ShortcutServiceTests.\(UUID().uuidString)")!
        let config = UserDefaultsConfig(defaults: defaults)
        let service = ShortcutService(config: config, registrationManager: FakeShortcutRegistrationManager())
        let invalidShortcut = ShortcutConfiguration(keyCode: UInt32(kVK_Escape), modifiers: UInt32(cmdKey))

        let state = service.register(configuration: invalidShortcut)

        XCTAssertEqual(state, .invalid(invalidShortcut))
        XCTAssertEqual(UserDefaultsConfig(defaults: defaults).shortcutConfiguration, .default)
    }

    func testRegisterConfiguration_whenRegistrationFails_shouldExposeConflict() {
        let manager = FakeShortcutRegistrationManager()
        manager.statusToReturn = OSStatus(eventHotKeyExistsErr)
        let service = ShortcutService(registrationManager: manager)
        let shortcut = ShortcutConfiguration(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey))

        let state = service.register(configuration: shortcut)

        XCTAssertEqual(state, .conflict(shortcut, OSStatus(eventHotKeyExistsErr)))
    }

    func testResetToDefaultShortcut_shouldRegisterAndPersistDefault() {
        let defaults = UserDefaults(suiteName: "ShortcutServiceTests.\(UUID().uuidString)")!
        var config = UserDefaultsConfig(defaults: defaults)
        config.shortcutConfiguration = ShortcutConfiguration(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey))
        let service = ShortcutService(config: config, registrationManager: FakeShortcutRegistrationManager())

        let state = service.resetToDefaultShortcut()

        XCTAssertEqual(state, .registered(.default))
        XCTAssertEqual(UserDefaultsConfig(defaults: defaults).shortcutConfiguration, .default)
    }
}

private final class FakeShortcutRegistrationManager: ShortcutRegistrationManaging {
    var registeredKeyCode: UInt32?
    var registeredModifiers: UInt32?
    var statusToReturn: OSStatus = noErr

    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        registeredKeyCode = keyCode
        registeredModifiers = modifiers
        return statusToReturn
    }

    func unregister() {}
}
