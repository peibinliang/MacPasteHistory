import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var shouldRecordText = DefaultSettings.shouldRecordText
    @Published var shouldRecordImage = DefaultSettings.shouldRecordImage
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
    @Published var showRestartAlert = false
    @Published var recordingPaused = false
    @Published var blockedApps: [BlockedAppEntry] = []
    @Published var blockedAppBundleID = ""
    @Published var blockedAppDisplayName = ""
    @Published var blockedAppErrorMessage: String?
    @Published var shortcutConfiguration: ShortcutConfiguration
    @Published var shortcutMessage: String?

    private var config: UserDefaultsConfig
    private let loginItemService: LoginItemService
    private let languageManager: LanguageManager
    private let appPreferencesService: AppPreferencesService
    let shortcutService: ShortcutService
    private let sourceApplicationProvider: SourceApplicationProviding

    init(
        config: UserDefaultsConfig = UserDefaultsConfig(),
        loginItemService: LoginItemService? = nil,
        languageManager: LanguageManager = LanguageManager(),
        appPreferencesService: AppPreferencesService? = nil,
        shortcutService: ShortcutService? = nil,
        sourceApplicationProvider: SourceApplicationProviding = SourceApplicationProvider()
    ) {
        self.config = config
        self.loginItemService = loginItemService ?? LoginItemService(config: config)
        self.languageManager = languageManager
        self.appPreferencesService = appPreferencesService ?? AppPreferencesService(config: config)
        self.shortcutService = shortcutService ?? ShortcutService(config: config)
        self.sourceApplicationProvider = sourceApplicationProvider
        self.selectedLanguage = languageManager.currentLanguage
        self.shortcutConfiguration = config.shortcutConfiguration
    }

    func loadSettings() {
        shouldRecordText = config.shouldRecordText
        shouldRecordImage = config.shouldRecordImage
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
    }

    func updateShouldRecordText(_ value: Bool) {
        config.shouldRecordText = value
    }

    func updateShouldRecordImage(_ value: Bool) {
        config.shouldRecordImage = value
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

    func updateRecordingPaused(_ value: Bool) {
        config.recordingPaused = value
        recordingPaused = value
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
}

extension Notification.Name {
    static let clearAllDataRequested = Notification.Name("clearAllDataRequested")
}
