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
    @Published var totalStorageCap = 250

    private var config = UserDefaultsConfig()

    func loadSettings() {
        shouldRecordText = config.shouldRecordText
        shouldRecordImage = config.shouldRecordImage
        launchAtStartup = config.launchAtStartup
        showDockIcon = config.showDockIcon
        historyRetentionDays = config.historyRetentionDays
        maxTextHistoryCount = config.maxTextHistoryCount
        maxImageHistoryCount = config.maxImageHistoryCount
        singleImageSizeLimit = config.maxImageSizeInBytes / (1024 * 1024)
        totalStorageCap = 250
    }

    func updateShouldRecordText(_ value: Bool) {
        config.shouldRecordText = value
    }

    func updateShouldRecordImage(_ value: Bool) {
        config.shouldRecordImage = value
    }

    func updateLaunchAtStartup(_ value: Bool) {
        config.launchAtStartup = value
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
        // Total storage cap is used by cleanup service.
        // Persisted via UserDefaults under a dedicated key could be added here.
    }

    func clearAllData() {
        // Post notification so AppDelegate can trigger repository + file cleanup
        NotificationCenter.default.post(name: .clearAllDataRequested, object: nil)
    }
}

extension Notification.Name {
    static let clearAllDataRequested = Notification.Name("clearAllDataRequested")
}
