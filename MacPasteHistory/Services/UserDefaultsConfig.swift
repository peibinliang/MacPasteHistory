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
        case appAppearance = "config.appAppearance"
        case recordingPaused = "config.recordingPaused"
        case blockedApps = "config.blockedApps"
        case shortcutKeyCode = "config.shortcutKeyCode"
        case shortcutModifiers = "config.shortcutModifiers"
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

    func string(forKey key: Key) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    func setString(_ value: String?, forKey key: Key) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
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
        get { positiveInteger(forKey: .maxTextHistoryCount, defaultValue: DefaultSettings.maxTextHistoryCount) }
        set { setInteger(newValue, forKey: .maxTextHistoryCount) }
    }

    var maxImageHistoryCount: Int {
        get { positiveInteger(forKey: .maxImageHistoryCount, defaultValue: DefaultSettings.maxImageHistoryCount) }
        set { setInteger(newValue, forKey: .maxImageHistoryCount) }
    }

    var maxImageSizeInBytes: Int {
        get { positiveInteger(forKey: .maxImageSizeInBytes, defaultValue: DefaultSettings.maxImageSizeInBytes) }
        set { setInteger(newValue, forKey: .maxImageSizeInBytes) }
    }

    var totalStorageCapInBytes: Int {
        get { positiveInteger(forKey: .totalStorageCapInBytes, defaultValue: DefaultSettings.totalStorageCapInBytes) }
        set { setInteger(newValue, forKey: .totalStorageCapInBytes) }
    }

    var historyRetentionDays: Int {
        get { positiveInteger(forKey: .historyRetentionDays, defaultValue: DefaultSettings.historyRetentionDays) }
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

    var appAppearance: AppAppearance {
        get {
            guard let value = string(forKey: .appAppearance),
                  let appearance = AppAppearance(rawValue: value) else {
                return .system
            }
            return appearance
        }
        set { setString(newValue.rawValue, forKey: .appAppearance) }
    }

    var recordingPaused: Bool {
        get { bool(forKey: .recordingPaused, defaultValue: false) }
        set { setBool(newValue, forKey: .recordingPaused) }
    }

    var blockedApps: [BlockedAppEntry] {
        get {
            guard let data = string(forKey: .blockedApps)?.data(using: .utf8),
                  let entries = try? JSONDecoder().decode([BlockedAppEntry].self, from: data) else {
                return []
            }
            return entries
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let value = String(data: data, encoding: .utf8) else {
                setString(nil, forKey: .blockedApps)
                return
            }
            setString(value, forKey: .blockedApps)
        }
    }

    var shortcutConfiguration: ShortcutConfiguration {
        get {
            guard defaults.object(forKey: Key.shortcutKeyCode.rawValue) != nil,
                  defaults.object(forKey: Key.shortcutModifiers.rawValue) != nil else {
                return .default
            }
            return ShortcutConfiguration(
                keyCode: UInt32(integer(forKey: .shortcutKeyCode, defaultValue: Int(ShortcutConfiguration.default.keyCode))),
                modifiers: UInt32(integer(forKey: .shortcutModifiers, defaultValue: Int(ShortcutConfiguration.default.modifiers)))
            )
        }
        set {
            setInteger(Int(newValue.keyCode), forKey: .shortcutKeyCode)
            setInteger(Int(newValue.modifiers), forKey: .shortcutModifiers)
        }
    }

    private func positiveInteger(forKey key: Key, defaultValue: Int) -> Int {
        let value = integer(forKey: key, defaultValue: defaultValue)
        return value > 0 ? value : defaultValue
    }
}
