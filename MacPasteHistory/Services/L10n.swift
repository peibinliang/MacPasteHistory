import Foundation

enum L10n {
    static func string(_ key: String, defaults: UserDefaults = .standard) -> String {
        let language = preferredLanguage(defaults: defaults)
        let languageCode = language.languageCode ?? systemLanguageCode(defaults: defaults)
        guard let languageCode,
              let bundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: bundlePath) else {
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
        let available = AppLanguage.allCases.compactMap(\.languageCode)
        let preferences = defaults.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        return Bundle.preferredLocalizations(from: available, forPreferences: preferences).first
    }
}
