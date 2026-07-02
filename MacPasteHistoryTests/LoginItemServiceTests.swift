import XCTest
@testable import MacPasteHistory

final class LoginItemServiceTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var config: UserDefaultsConfig!
    private var manager: FakeLoginItemManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaultsSuiteName = "LoginItemServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
        config = UserDefaultsConfig(defaults: defaults)
        manager = FakeLoginItemManager()
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        manager = nil
        config = nil
        defaults = nil
        defaultsSuiteName = nil
        try super.tearDownWithError()
    }

    func testSetLaunchAtLoginEnabled_whenEnabled_shouldRegisterAndPersistSetting() throws {
        let service = LoginItemService(manager: manager, config: config)

        try service.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertEqual(manager.unregisterCallCount, 0)
        XCTAssertTrue(config.launchAtStartup)
    }

    func testSetLaunchAtLoginEnabled_whenDisabled_shouldUnregisterAndPersistSetting() throws {
        config.launchAtStartup = true
        let service = LoginItemService(manager: manager, config: config)

        try service.setLaunchAtLoginEnabled(false)

        XCTAssertEqual(manager.registerCallCount, 0)
        XCTAssertEqual(manager.unregisterCallCount, 1)
        XCTAssertFalse(config.launchAtStartup)
    }

    func testSetLaunchAtLoginEnabled_whenRegisterFails_shouldNotPersistEnabledSetting() throws {
        manager.errorToThrow = LoginItemTestError.failed
        let service = LoginItemService(manager: manager, config: config)

        XCTAssertThrowsError(try service.setLaunchAtLoginEnabled(true))

        XCTAssertFalse(config.launchAtStartup)
    }
}

private final class FakeLoginItemManager: LoginItemManaging {
    var registerCallCount = 0
    var unregisterCallCount = 0
    var errorToThrow: Error?

    func register() throws {
        registerCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
    }
}

private enum LoginItemTestError: Error {
    case failed
}
