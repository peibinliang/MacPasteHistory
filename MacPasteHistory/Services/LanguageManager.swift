import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .system:
            return L10n.string("Follow System")
        case .en:
            return L10n.string("English")
        case .zhHans:
            return L10n.string("简体中文")
        case .zhHant:
            return L10n.string("繁體中文")
        }
    }

    var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .en:
            return "en"
        case .zhHans:
            return "zh-Hans"
        case .zhHant:
            return "zh-Hant"
        }
    }
}

final class LanguageManager {
    static let defaultLanguage: AppLanguage = .system
    static let preferredLanguageKey = "config.preferredLanguage"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentLanguage: AppLanguage {
        guard let rawValue = defaults.string(forKey: Self.preferredLanguageKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return Self.defaultLanguage
        }
        return language
    }

    func setLanguage(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Self.preferredLanguageKey)
        applyLanguage(language)
    }

    func applyLanguage(_ language: AppLanguage) {
        if let code = language.languageCode {
            defaults.set([code], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }

    func applyCurrentLanguage() {
        applyLanguage(currentLanguage)
    }
}
