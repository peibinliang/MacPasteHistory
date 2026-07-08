import Foundation

/// Type-safe wrapper around `UserDefaults` for persisting app settings.
/// Writes are immediately synchronized; reads fall back to `DefaultDefaults` when no value exists.
struct UserDefaultsConfig {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    enum Key: String {
        case shouldRecordText = "config.shouldRecordText"
        case shouldRecordImage = "config.shouldRecordImage"
        case maxTextHistoryCount = "config.maxTextHistoryCount"
        case maxImageHistoryCount = "config.maxImageHistoryCount"
        case maxImageSizeInBytes = "config.maxImageSizeInBytes"
        case totalStorageCapInBytes = "config.totalStorageCapInBytes"
        case historyRetentionDays = "config.historyRetentionDays"
        case launchAtStartup = "config.launchAtStartup"
        case showDockIcon = "config.showDockIcon"
        case preferredLanguage = "config.preferredLanguage"
    }

    // MARK: - Generic accessors

    func bool(forKey key: Key, defaultValue: Bool) -> Bool {
        defaults.object(forKey: key.rawValue) == nil ? defaultValue : defaults.bool(forKey: key.rawValue)
    }

    func integer(forKey key: Key, defaultValue: Int) -> Int {
        defaults.object(forKey: key.rawValue) == nil ? defaultValue : defaults.integer(forKey: key.rawValue)
    }

    func setBool(_ value: Bool, forKey key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    func setInteger(_ value: Int, forKey key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    func removeValue(forKey key: Key) {
        defaults.removeObject(forKey: key.rawValue)
    }

    // MARK: - Convenience properties

    var shouldRecordText: Bool {
        get { bool(forKey: .shouldRecordText, defaultValue: DefaultSettings.shouldRecordText) }
        set { setBool(newValue, forKey: .shouldRecordText) }
    }

    var shouldRecordImage: Bool {
        get { bool(forKey: .shouldRecordImage, defaultValue: DefaultSettings.shouldRecordImage) }
        set { setBool(newValue, forKey: .shouldRecordImage) }
    }

    var maxTextHistoryCount: Int {
        get { integer(forKey: .maxTextHistoryCount, defaultValue: DefaultSettings.maxTextHistoryCount) }
        set { setInteger(newValue, forKey: .maxTextHistoryCount) }
    }

    var maxImageHistoryCount: Int {
        get { integer(forKey: .maxImageHistoryCount, defaultValue: DefaultSettings.maxImageHistoryCount) }
        set { setInteger(newValue, forKey: .maxImageHistoryCount) }
    }

    var maxImageSizeInBytes: Int {
        get { integer(forKey: .maxImageSizeInBytes, defaultValue: DefaultSettings.maxImageSizeInBytes) }
        set { setInteger(newValue, forKey: .maxImageSizeInBytes) }
    }

    var totalStorageCapInBytes: Int {
        get { integer(forKey: .totalStorageCapInBytes, defaultValue: DefaultSettings.totalStorageCapInBytes) }
        set { setInteger(newValue, forKey: .totalStorageCapInBytes) }
    }

    var historyRetentionDays: Int {
        get { integer(forKey: .historyRetentionDays, defaultValue: DefaultSettings.historyRetentionDays) }
        set { setInteger(newValue, forKey: .historyRetentionDays) }
    }

    var launchAtStartup: Bool {
        get { bool(forKey: .launchAtStartup, defaultValue: false) }
        set { setBool(newValue, forKey: .launchAtStartup) }
    }

    var showDockIcon: Bool {
        get { bool(forKey: .showDockIcon, defaultValue: false) }
        set { setBool(newValue, forKey: .showDockIcon) }
    }

    var preferredLanguage: String? {
        get { defaults.string(forKey: Key.preferredLanguage.rawValue) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.preferredLanguage.rawValue)
            } else {
                defaults.removeObject(forKey: Key.preferredLanguage.rawValue)
            }
        }
    }
}
