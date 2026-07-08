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
    @Published var selectedLanguage: AppLanguage
    @Published var showRestartAlert = false

    private var config: UserDefaultsConfig
    private let loginItemService: LoginItemService
    private let languageManager: LanguageManager

    init(config: UserDefaultsConfig = UserDefaultsConfig(), loginItemService: LoginItemService? = nil, languageManager: LanguageManager = LanguageManager()) {
        self.config = config
        self.loginItemService = loginItemService ?? LoginItemService(config: config)
        self.languageManager = languageManager
        self.selectedLanguage = languageManager.currentLanguage
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
            launchAtStartupErrorMessage = NSLocalizedString("Unable to update the login item. Check macOS Login Items permissions and try again.", comment: "Error: login item update failed")
        }
    }

    func updateShowDockIcon(_ value: Bool) {
        config.showDockIcon = value
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
}

extension Notification.Name {
    static let clearAllDataRequested = Notification.Name("clearAllDataRequested")
}
