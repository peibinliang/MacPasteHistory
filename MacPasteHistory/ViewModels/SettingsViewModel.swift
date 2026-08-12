import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var shouldRecordText = DefaultSettings.shouldRecordText
    @Published var shouldRecordImage = DefaultSettings.shouldRecordImage
    @Published var filterSensitiveContent = DefaultSettings.filterSensitiveContent
    @Published var showSensitiveContentWarning = false
    @Published var launchAtStartup = false
    @Published var showDockIcon = false
    @Published var historyRetentionDays = DefaultSettings.historyRetentionDays
    @Published var maxTextHistoryCount = DefaultSettings.maxTextHistoryCount
    @Published var maxImageHistoryCount = DefaultSettings.maxImageHistoryCount
    @Published var singleImageSizeLimit = 20
    @Published var totalStorageCap = DefaultSettings.totalStorageCapInBytes / (1024 * 1024)
    @Published var launchAtStartupErrorMessage: String?
    @Published var appPreferenceMessage: String?
    @Published var selectedLanguage: AppLanguage
    @Published var selectedAppearance: AppAppearance
    @Published var showRestartAlert = false
    @Published var recordingPaused = false
    @Published var blockedApps: [BlockedAppEntry] = []
    @Published var blockedAppBundleID = ""
    @Published var blockedAppDisplayName = ""
    @Published var blockedAppErrorMessage: String?
    @Published var shortcutConfiguration: ShortcutConfiguration
    @Published var shortcutMessage: String?
    @Published var automaticPasteEnabled = DefaultSettings.automaticPasteEnabled
    @Published private(set) var isAutomaticPastePermissionRequired = false
    @Published var aiModelIdentifier = DefaultSettings.aiModelIdentifier {
        didSet {
            let normalizedValue = aiModelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedValue.isEmpty == false,
                  normalizedValue != config.aiModelIdentifier else { return }
            config.aiModelIdentifier = normalizedValue
            refreshAITokenUsage()
        }
    }
    @Published var aiAPIKeyEntry = ""
    @Published private(set) var hasStoredAIAPIKey = false
    @Published var aiCredentialMessage: String?
    @Published private(set) var allModelsAIUsage = AITokenUsageSummary.zero
    @Published private(set) var selectedModelAIUsage = AITokenUsageSummary.zero

    private var config: UserDefaultsConfig
    private let loginItemService: LoginItemService
    private let languageManager: LanguageManager
    private let appPreferencesService: AppPreferencesService
    private let appearanceService: AppearanceService
    let shortcutService: ShortcutService
    private let sourceApplicationProvider: SourceApplicationProviding
    private let accessibilityPermissionService: any AccessibilityPermissionServing
    private let aiCredentialStore: any AICredentialStoring
    private let aiTokenUsageRepository: AITokenUsageRepository?
    private var aiTokenUsageDidChangeCancellable: AnyCancellable?

    init(
        config: UserDefaultsConfig = UserDefaultsConfig(),
        loginItemService: LoginItemService? = nil,
        languageManager: LanguageManager = LanguageManager(),
        appPreferencesService: AppPreferencesService? = nil,
        appearanceService: AppearanceService? = nil,
        shortcutService: ShortcutService? = nil,
        sourceApplicationProvider: SourceApplicationProviding = SourceApplicationProvider(),
        accessibilityPermissionService: any AccessibilityPermissionServing = AccessibilityPermissionService(),
        aiCredentialStore: any AICredentialStoring = KeychainAICredentialStore(),
        aiTokenUsageRepository: AITokenUsageRepository? = nil
    ) {
        self.config = config
        self.loginItemService = loginItemService ?? LoginItemService(config: config)
        self.languageManager = languageManager
        self.appPreferencesService = appPreferencesService ?? AppPreferencesService(config: config)
        self.appearanceService = appearanceService ?? AppearanceService(config: config)
        self.shortcutService = shortcutService ?? ShortcutService(config: config)
        self.sourceApplicationProvider = sourceApplicationProvider
        self.accessibilityPermissionService = accessibilityPermissionService
        self.aiCredentialStore = aiCredentialStore
        self.aiTokenUsageRepository = aiTokenUsageRepository
        self.selectedLanguage = languageManager.currentLanguage
        self.selectedAppearance = config.appAppearance
        self.shortcutConfiguration = config.shortcutConfiguration
        aiTokenUsageDidChangeCancellable = NotificationCenter.default.publisher(for: .aiTokenUsageDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAITokenUsage()
            }
    }

    func loadSettings() {
        shouldRecordText = config.shouldRecordText
        shouldRecordImage = config.shouldRecordImage
        filterSensitiveContent = config.filterSensitiveContent
        launchAtStartup = config.launchAtStartup
        showDockIcon = config.showDockIcon
        historyRetentionDays = config.historyRetentionDays
        maxTextHistoryCount = config.maxTextHistoryCount
        maxImageHistoryCount = config.maxImageHistoryCount
        singleImageSizeLimit = config.maxImageSizeInBytes / (1024 * 1024)
        totalStorageCap = config.totalStorageCapInBytes / (1024 * 1024)
        recordingPaused = config.recordingPaused
        blockedApps = config.blockedApps
        shortcutConfiguration = config.shortcutConfiguration
        selectedAppearance = config.appAppearance
        automaticPasteEnabled = config.automaticPasteEnabled
        aiModelIdentifier = config.aiModelIdentifier
        refreshAutomaticPastePermissionState()
        refreshAISettingsState()
    }

    func updateShouldRecordText(_ value: Bool) {
        config.shouldRecordText = value
    }

    func updateShouldRecordImage(_ value: Bool) {
        config.shouldRecordImage = value
    }

    func requestSensitiveContentFiltering(_ enabled: Bool) {
        if enabled {
            config.filterSensitiveContent = true
            filterSensitiveContent = true
            return
        }

        guard config.hasAcknowledgedSensitiveContentRisk else {
            filterSensitiveContent = true
            showSensitiveContentWarning = true
            return
        }

        config.filterSensitiveContent = false
        filterSensitiveContent = false
    }

    func confirmSensitiveContentFilteringDisabled() {
        config.hasAcknowledgedSensitiveContentRisk = true
        config.filterSensitiveContent = false
        filterSensitiveContent = false
        showSensitiveContentWarning = false
    }

    func cancelSensitiveContentFilteringDisabled() {
        filterSensitiveContent = true
        showSensitiveContentWarning = false
    }

    func updateLaunchAtStartup(_ value: Bool) {
        do {
            try loginItemService.setLaunchAtLoginEnabled(value)
            launchAtStartup = config.launchAtStartup
            launchAtStartupErrorMessage = nil
        } catch {
            launchAtStartup = config.launchAtStartup
            launchAtStartupErrorMessage = L10n.string("Unable to update the login item. Check macOS Login Items permissions and try again.")
        }
    }

    func updateShowDockIcon(_ value: Bool) {
        let result = appPreferencesService.setDockIconVisible(value)
        appPreferenceMessage = result == .restartRequired
            ? L10n.string("Restart the app to finish applying the Dock icon setting.")
            : nil
    }

    func updateHistoryRetentionDays(_ value: Int) {
        config.historyRetentionDays = value
    }

    func updateMaxTextHistoryCount(_ value: Int) {
        config.maxTextHistoryCount = value
    }

    func updateMaxImageHistoryCount(_ value: Int) {
        config.maxImageHistoryCount = value
    }

    func updateSingleImageSizeLimit(_ megabytes: Int) {
        config.maxImageSizeInBytes = megabytes * 1024 * 1024
    }

    func updateTotalStorageCap(_ megabytes: Int) {
        config.totalStorageCapInBytes = megabytes * 1024 * 1024
    }

    func clearAllData() {
        // Post notification so AppDelegate can trigger repository + file cleanup
        NotificationCenter.default.post(name: .clearAllDataRequested, object: nil)
    }

    func updateLanguage(_ language: AppLanguage) {
        languageManager.setLanguage(language)
        selectedLanguage = language
        showRestartAlert = true
    }

    func updateAppearance(_ appearance: AppAppearance) {
        appearanceService.setAppearance(appearance)
        selectedAppearance = appearance
    }

    func updateRecordingPaused(_ value: Bool) {
        config.recordingPaused = value
        recordingPaused = value
    }

    func updateAutomaticPasteEnabled(_ value: Bool) {
        config.automaticPasteEnabled = value
        automaticPasteEnabled = value
        refreshAutomaticPastePermissionState()
    }

    func openAccessibilitySettings() {
        accessibilityPermissionService.openSystemSettings()
    }

    func updateAIModelIdentifier(_ value: String) {
        config.aiModelIdentifier = value
        aiModelIdentifier = config.aiModelIdentifier
        refreshAITokenUsage()
    }

    func resetAIModelIdentifier() {
        config.removeValue(forKey: .aiModelIdentifier)
        aiModelIdentifier = config.aiModelIdentifier
        refreshAITokenUsage()
    }

    func saveAIAPIKey() {
        do {
            try aiCredentialStore.saveAPIKey(aiAPIKeyEntry)
            aiAPIKeyEntry = ""
            hasStoredAIAPIKey = true
            aiCredentialMessage = L10n.string("ai.settings.key-saved")
        } catch {
            aiCredentialMessage = L10n.string("ai.settings.key-save-failed")
        }
    }

    func removeAIAPIKey() {
        do {
            try aiCredentialStore.deleteAPIKey()
            aiAPIKeyEntry = ""
            hasStoredAIAPIKey = false
            aiCredentialMessage = L10n.string("ai.settings.key-removed")
        } catch {
            aiCredentialMessage = L10n.string("ai.settings.key-remove-failed")
        }
    }

    func addBlockedAppFromFields() {
        let bundleID = blockedAppBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = blockedAppDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        addBlockedApp(bundleID: bundleID, displayName: displayName.isEmpty ? bundleID : displayName)
    }

    func addCurrentForegroundAppToBlockedApps() {
        let source = sourceApplicationProvider.currentSourceApplication()
        guard let bundleID = source.bundleID else {
            blockedAppErrorMessage = L10n.string("Unable to detect the current app.")
            return
        }
        addBlockedApp(bundleID: bundleID, displayName: source.name ?? bundleID)
    }

    func setBlockedAppEnabled(_ entry: BlockedAppEntry, isEnabled: Bool) {
        var entries = config.blockedApps
        guard let index = entries.firstIndex(where: { $0.bundleID == entry.bundleID }) else { return }
        entries[index].isEnabled = isEnabled
        entries[index].updatedAt = Date()
        config.blockedApps = entries
        blockedApps = entries
    }

    func removeBlockedApp(_ entry: BlockedAppEntry) {
        let entries = config.blockedApps.filter { $0.bundleID != entry.bundleID }
        config.blockedApps = entries
        blockedApps = entries
    }

    func updateShortcut(_ shortcut: ShortcutConfiguration) {
        let state = shortcutService.register(configuration: shortcut)
        shortcutConfiguration = config.shortcutConfiguration
        switch state {
        case .registered(let configuration):
            shortcutConfiguration = configuration
            shortcutMessage = nil
        case .invalid:
            shortcutMessage = L10n.string("Choose a shortcut with at least one modifier and a non-reserved key.")
        case .conflict(_, let status):
            shortcutMessage = String(format: L10n.string("Shortcut registration failed (%lld). Choose another shortcut."), Int64(status))
        case .unregistered:
            shortcutMessage = L10n.string("Shortcut is not registered.")
        }
    }

    func resetShortcut() {
        updateShortcut(.default)
    }

    private func addBlockedApp(bundleID: String, displayName: String) {
        guard BlockedAppEntry.isValidBundleID(bundleID) else {
            blockedAppErrorMessage = L10n.string("Enter a valid bundle identifier, for example com.apple.Safari.")
            return
        }
        var entries = config.blockedApps
        let now = Date()
        if let index = entries.firstIndex(where: { $0.bundleID == bundleID }) {
            entries[index].displayName = displayName
            entries[index].isEnabled = true
            entries[index].updatedAt = now
        } else {
            entries.append(BlockedAppEntry(bundleID: bundleID, displayName: displayName, createdAt: now, updatedAt: now))
        }
        config.blockedApps = entries.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        blockedApps = config.blockedApps
        blockedAppBundleID = ""
        blockedAppDisplayName = ""
        blockedAppErrorMessage = nil
    }

    func refreshAutomaticPastePermissionState() {
        isAutomaticPastePermissionRequired = automaticPasteEnabled
            && accessibilityPermissionService.hasAccessibilityPermission == false
    }

    private func refreshAISettingsState() {
        do {
            hasStoredAIAPIKey = try aiCredentialStore.hasAPIKey()
        } catch {
            hasStoredAIAPIKey = false
            aiCredentialMessage = L10n.string("ai.settings.key-status-failed")
        }
        refreshAITokenUsage()
    }

    private func refreshAITokenUsage() {
        guard let aiTokenUsageRepository else {
            allModelsAIUsage = .zero
            selectedModelAIUsage = .zero
            return
        }
        do {
            allModelsAIUsage = try aiTokenUsageRepository.summary()
            selectedModelAIUsage = try aiTokenUsageRepository.summary(modelIdentifier: aiModelIdentifier)
        } catch {
            allModelsAIUsage = .zero
            selectedModelAIUsage = .zero
        }
    }
}

extension Notification.Name {
    static let clearAllDataRequested = Notification.Name("clearAllDataRequested")
    static let aiTokenUsageDidChange = Notification.Name("aiTokenUsageDidChange")
}
