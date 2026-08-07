import XCTest
import Carbon
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
    func testUpdateRecordingPaused_shouldPersistPauseState() {
        let viewModel = makeViewModel()

        viewModel.updateRecordingPaused(true)

        XCTAssertTrue(config.recordingPaused)
        XCTAssertTrue(viewModel.recordingPaused)
    }

    @MainActor
    func testLoadAndUpdateAppearance_shouldPersistAndApplyImmediately() {
        config.appAppearance = .dark
        var appliedAppearances: [AppAppearance] = []
        let appearanceService = AppearanceService(config: config) { appearance in
            appliedAppearances.append(appearance)
        }
        let viewModel = makeViewModel(appearanceService: appearanceService)

        viewModel.loadSettings()
        XCTAssertEqual(viewModel.selectedAppearance, .dark)

        viewModel.updateAppearance(.light)

        XCTAssertEqual(config.appAppearance, .light)
        XCTAssertEqual(viewModel.selectedAppearance, .light)
        XCTAssertEqual(appliedAppearances, [.light])
    }

    @MainActor
    func testAddBlockedAppFromFields_shouldPersistBlockedAppEntry() {
        let viewModel = makeViewModel()
        viewModel.blockedAppBundleID = "com.apple.Safari"
        viewModel.blockedAppDisplayName = "Safari"

        viewModel.addBlockedAppFromFields()

        XCTAssertEqual(config.blockedApps.map(\.bundleID), ["com.apple.Safari"])
        XCTAssertEqual(viewModel.blockedApps.first?.displayName, "Safari")
    }

    @MainActor
    func testAddCurrentForegroundAppToBlockedApps_shouldUseSourceApplicationProvider() {
        let viewModel = makeViewModel(sourceApplicationProvider: SettingsStubSourceApplicationProvider())

        viewModel.addCurrentForegroundAppToBlockedApps()

        XCTAssertEqual(config.blockedApps.map(\.bundleID), ["com.example.Foreground"])
    }

    @MainActor
    func testUpdateShortcut_whenValid_shouldPersistShortcut() {
        let shortcutManager = SettingsFakeShortcutRegistrationManager()
        let shortcutService = ShortcutService(config: config, registrationManager: shortcutManager)
        let viewModel = makeViewModel(shortcutService: shortcutService)
        let shortcut = ShortcutConfiguration(keyCode: 11, modifiers: 1_280)

        viewModel.updateShortcut(shortcut)

        XCTAssertEqual(config.shortcutConfiguration, shortcut)
        XCTAssertNil(viewModel.shortcutMessage)
    }

    @MainActor
    private func makeViewModel(
        shortcutService: ShortcutService? = nil,
        appearanceService: AppearanceService? = nil,
        sourceApplicationProvider: SourceApplicationProviding = SourceApplicationProvider()
    ) -> SettingsViewModel {
        let service = LoginItemService(manager: manager, config: config)
        let appPreferencesService = AppPreferencesService(config: config) { _ in true }
        return SettingsViewModel(
            config: config,
            loginItemService: service,
            appPreferencesService: appPreferencesService,
            appearanceService: appearanceService,
            shortcutService: shortcutService,
            sourceApplicationProvider: sourceApplicationProvider
        )
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

private struct SettingsStubSourceApplicationProvider: SourceApplicationProviding {
    func currentSourceApplication() -> SourceApplication {
        SourceApplication(name: "Foreground", bundleID: "com.example.Foreground")
    }
}

private final class SettingsFakeShortcutRegistrationManager: ShortcutRegistrationManaging {
    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        noErr
    }

    func unregister() {}
}
