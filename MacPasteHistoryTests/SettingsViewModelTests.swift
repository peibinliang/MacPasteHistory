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
    func testRequestSensitiveFilteringDisabled_whenRiskNotAcknowledged_shouldKeepEnabledAndRequestConfirmation() {
        let viewModel = makeViewModel()
        viewModel.loadSettings()

        viewModel.requestSensitiveContentFiltering(false)

        XCTAssertTrue(viewModel.filterSensitiveContent)
        XCTAssertTrue(viewModel.showSensitiveContentWarning)
        XCTAssertTrue(config.filterSensitiveContent)
    }

    @MainActor
    func testConfirmSensitiveFilteringDisabled_shouldPersistChoiceAndAcknowledgement() {
        let viewModel = makeViewModel()

        viewModel.requestSensitiveContentFiltering(false)
        viewModel.confirmSensitiveContentFilteringDisabled()

        XCTAssertFalse(viewModel.filterSensitiveContent)
        XCTAssertFalse(viewModel.showSensitiveContentWarning)
        XCTAssertFalse(config.filterSensitiveContent)
        XCTAssertTrue(config.hasAcknowledgedSensitiveContentRisk)
    }

    @MainActor
    func testRequestSensitiveFilteringDisabled_whenRiskAlreadyAcknowledged_shouldDisableImmediately() {
        config.hasAcknowledgedSensitiveContentRisk = true
        let viewModel = makeViewModel()
        viewModel.loadSettings()

        viewModel.requestSensitiveContentFiltering(false)

        XCTAssertFalse(viewModel.filterSensitiveContent)
        XCTAssertFalse(viewModel.showSensitiveContentWarning)
    }

    @MainActor
    func testUpdateAutomaticPaste_withoutPermission_shouldPersistEnabledPendingState() {
        let accessibilityService = SettingsFakeAccessibilityPermissionService(hasPermission: false)
        let viewModel = makeViewModel(accessibilityPermissionService: accessibilityService)

        viewModel.updateAutomaticPasteEnabled(true)

        XCTAssertTrue(config.automaticPasteEnabled)
        XCTAssertTrue(viewModel.automaticPasteEnabled)
        XCTAssertTrue(viewModel.isAutomaticPastePermissionRequired)
    }

    @MainActor
    func testUpdateAutomaticPaste_withPermission_shouldBecomeReady() {
        let accessibilityService = SettingsFakeAccessibilityPermissionService(hasPermission: true)
        let viewModel = makeViewModel(accessibilityPermissionService: accessibilityService)

        viewModel.updateAutomaticPasteEnabled(true)

        XCTAssertFalse(viewModel.isAutomaticPastePermissionRequired)
    }

    @MainActor
    func testUpdateAutomaticPaste_whenDisabled_shouldStopRequiringPermission() {
        config.automaticPasteEnabled = true
        let accessibilityService = SettingsFakeAccessibilityPermissionService(hasPermission: false)
        let viewModel = makeViewModel(accessibilityPermissionService: accessibilityService)

        viewModel.updateAutomaticPasteEnabled(false)

        XCTAssertFalse(config.automaticPasteEnabled)
        XCTAssertFalse(viewModel.automaticPasteEnabled)
        XCTAssertFalse(viewModel.isAutomaticPastePermissionRequired)
    }

    @MainActor
    func testRefreshAutomaticPastePermissionState_afterReturningFromSystemSettings_shouldUseCurrentPermission() {
        config.automaticPasteEnabled = true
        let accessibilityService = SettingsFakeAccessibilityPermissionService(hasPermission: false)
        let viewModel = makeViewModel(accessibilityPermissionService: accessibilityService)
        viewModel.loadSettings()
        XCTAssertTrue(viewModel.isAutomaticPastePermissionRequired)

        accessibilityService.hasAccessibilityPermission = true
        viewModel.refreshAutomaticPastePermissionState()

        XCTAssertFalse(viewModel.isAutomaticPastePermissionRequired)
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
    func testAISettings_shouldPersistModelAndKeepCredentialEntryTransient() {
        let credentialStore = SettingsFakeAICredentialStore()
        let viewModel = makeViewModel(aiCredentialStore: credentialStore)

        viewModel.updateAIModelIdentifier(" custom-model ")
        viewModel.aiAPIKeyEntry = "synthetic-key"
        viewModel.saveAIAPIKey()

        XCTAssertEqual(config.aiModelIdentifier, "custom-model")
        XCTAssertEqual(viewModel.aiModelIdentifier, "custom-model")
        XCTAssertEqual(viewModel.aiAPIKeyEntry, "")
        XCTAssertTrue(viewModel.hasStoredAIAPIKey)
        XCTAssertEqual(credentialStore.apiKey, "synthetic-key")
    }

    @MainActor
    func testAIModelEditing_shouldPersistWithoutSubmittingTheTextField() {
        let viewModel = makeViewModel()

        viewModel.aiModelIdentifier = "custom-model-without-submit"

        XCTAssertEqual(config.aiModelIdentifier, "custom-model-without-submit")
    }

    @MainActor
    func testAISettings_shouldLoadProviderReportedAllAndCurrentModelTotals() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let repository = AITokenUsageRepository(database: temporary.connection)
        try repository.insert(AITokenUsageRecord(
            requestID: "usage-1", provider: "deepseek", modelIdentifier: DefaultSettings.aiModelIdentifier,
            inputTokens: 7, outputTokens: 3, totalTokens: 10, cachedInputTokens: nil, createdAt: Date()
        ))
        try repository.insert(AITokenUsageRecord(
            requestID: "usage-2", provider: "deepseek", modelIdentifier: "another-model",
            inputTokens: 4, outputTokens: 2, totalTokens: 6, cachedInputTokens: nil, createdAt: Date()
        ))
        let viewModel = makeViewModel(aiTokenUsageRepository: repository)

        viewModel.loadSettings()

        XCTAssertEqual(viewModel.selectedModelAIUsage.totalTokens, 10)
        XCTAssertEqual(viewModel.allModelsAIUsage.totalTokens, 16)
    }

    @MainActor
    func testAISettings_whenPolishingPersistsUsage_shouldRefreshExistingTotals() async throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let repository = AITokenUsageRepository(database: temporary.connection)
        let credentialStore = SettingsFakeAICredentialStore()
        credentialStore.apiKey = "synthetic-key"
        let response = DeepSeekPolishingResult(
            requestID: "settings-refresh",
            modelIdentifier: config.aiModelIdentifier,
            polishedText: "Polished",
            usage: DeepSeekTokenUsage(inputTokens: 7, outputTokens: 3, totalTokens: 10, cachedInputTokens: nil)
        )
        let viewModel = makeViewModel(aiTokenUsageRepository: repository)
        let service = AITextPolishingService(
            config: config,
            credentialStore: credentialStore,
            client: SettingsTokenUsageClientFake(response: response),
            usageRepository: repository
        )
        viewModel.loadSettings()
        XCTAssertEqual(viewModel.allModelsAIUsage, .zero)

        _ = try await service.polish("draft")
        for _ in 0..<100 where viewModel.allModelsAIUsage.totalTokens == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(viewModel.selectedModelAIUsage.totalTokens, 10)
        XCTAssertEqual(viewModel.allModelsAIUsage.totalTokens, 10)
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
        sourceApplicationProvider: SourceApplicationProviding = SourceApplicationProvider(),
        accessibilityPermissionService: AccessibilityPermissionServing = AccessibilityPermissionService(),
        aiCredentialStore: AICredentialStoring = SettingsFakeAICredentialStore(),
        aiTokenUsageRepository: AITokenUsageRepository? = nil
    ) -> SettingsViewModel {
        let service = LoginItemService(manager: manager, config: config)
        let appPreferencesService = AppPreferencesService(config: config) { _ in true }
        return SettingsViewModel(
            config: config,
            loginItemService: service,
            appPreferencesService: appPreferencesService,
            appearanceService: appearanceService,
            shortcutService: shortcutService,
            sourceApplicationProvider: sourceApplicationProvider,
            accessibilityPermissionService: accessibilityPermissionService,
            aiCredentialStore: aiCredentialStore,
            aiTokenUsageRepository: aiTokenUsageRepository
        )
    }
}

private final class SettingsFakeAICredentialStore: AICredentialStoring, @unchecked Sendable {
    var apiKey: String?
    func readAPIKey() throws -> String? { apiKey }
    func hasAPIKey() throws -> Bool { apiKey != nil }
    func saveAPIKey(_ apiKey: String) throws { self.apiKey = apiKey }
    func deleteAPIKey() throws { apiKey = nil }
}

private final class SettingsTokenUsageClientFake: DeepSeekClientProtocol, @unchecked Sendable {
    private let response: DeepSeekPolishingResult

    init(response: DeepSeekPolishingResult) {
        self.response = response
    }

    func polish(text: String, modelIdentifier: String, apiKey: String) async throws -> DeepSeekPolishingResult {
        response
    }
}

private final class SettingsFakeAccessibilityPermissionService: AccessibilityPermissionServing {
    var hasAccessibilityPermission: Bool
    private(set) var openSettingsCallCount = 0

    init(hasPermission: Bool) {
        hasAccessibilityPermission = hasPermission
    }

    func openSystemSettings() {
        openSettingsCallCount += 1
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
