import Foundation

enum DefaultSettings {
    static let clipboardPollingInterval: TimeInterval = 0.5
    static let maxTextHistoryCount = 1_000
    static let maxImageHistoryCount = 100
    static let maxImageSizeInBytes = 20 * 1024 * 1024
    static let totalStorageCapInBytes = 250 * 1024 * 1024
    static let historyRetentionDays = 30
    static let captureEventAggregationRetentionDays = 30
    static let shouldRecordText = true
    static let shouldRecordImage = true
    static let filterSensitiveContent = true
    static let automaticPasteEnabled = false
    static let aiModelIdentifier = "deepseek-v4-flash"
}
