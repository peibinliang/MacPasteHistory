import XCTest
@testable import MacPasteHistory

final class SettingsViewModelTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var config: UserDefaultsConfig!
    private var manager: SettingsFakeLoginItemManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaultsSuiteName = "SettingsViewModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
        config = UserDefaultsConfig(defaults: defaults)
        manager = SettingsFakeLoginItemManager()
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        manager = nil
        config = nil
        defaults = nil
        defaultsSuiteName = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testUpdateLaunchAtStartup_whenEnabled_shouldRegisterLoginItemAndUpdateState() {
        let viewModel = makeViewModel()

        viewModel.updateLaunchAtStartup(true)

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertTrue(viewModel.launchAtStartup)
        XCTAssertTrue(config.launchAtStartup)
        XCTAssertNil(viewModel.launchAtStartupErrorMessage)
    }

    @MainActor
    func testUpdateLaunchAtStartup_whenRegistrationFails_shouldRollbackStateAndExposeError() {
        manager.errorToThrow = SettingsLoginItemTestError.failed
        let viewModel = makeViewModel()

        viewModel.updateLaunchAtStartup(true)

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertFalse(viewModel.launchAtStartup)
        XCTAssertFalse(config.launchAtStartup)
        XCTAssertNotNil(viewModel.launchAtStartupErrorMessage)
    }

    @MainActor
    private func makeViewModel() -> SettingsViewModel {
        let service = LoginItemService(manager: manager, config: config)
        return SettingsViewModel(config: config, loginItemService: service)
    }
}

private final class SettingsFakeLoginItemManager: LoginItemManaging {
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

private enum SettingsLoginItemTestError: Error {
    case failed
}
