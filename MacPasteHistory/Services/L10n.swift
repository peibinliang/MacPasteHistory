import Foundation

enum L10n {
    private static let availableLanguageCodes = AppLanguage.allCases.compactMap(\.languageCode)
    private static let bundleCache = LocalizationBundleCache()

    static func string(_ key: String, defaults: UserDefaults = .standard) -> String {
        let language = preferredLanguage(defaults: defaults)
        let languageCode = language.languageCode ?? systemLanguageCode(defaults: defaults)
        guard let languageCode,
              let bundle = bundleCache.bundle(for: languageCode) else {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static func preferredLanguage(defaults: UserDefaults) -> AppLanguage {
        guard let rawValue = defaults.string(forKey: LanguageManager.preferredLanguageKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return .system
        }
        return language
    }

    private static func systemLanguageCode(defaults: UserDefaults) -> String? {
        let preferences = defaults.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        return Bundle.preferredLocalizations(from: availableLanguageCodes, forPreferences: preferences).first
    }
}

private final class LocalizationBundleCache: @unchecked Sendable {
    private let lock = NSLock()
    private var bundlesByLanguageCode: [String: Bundle] = [:]

    func bundle(for languageCode: String) -> Bundle? {
        lock.lock()
        if let cached = bundlesByLanguageCode[languageCode] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let bundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let loadedBundle = Bundle(path: bundlePath) else {
            return nil
        }

        lock.lock()
        bundlesByLanguageCode[languageCode] = loadedBundle
        lock.unlock()
        return loadedBundle
    }
}
