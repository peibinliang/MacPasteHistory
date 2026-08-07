import Foundation

enum DetectedContentType: String, CaseIterable, Codable {
    case plainText
    case image
    case json
    case url
    case base64
    case jwt
    case timestamp
    case sql
    case shell

    var localizationKey: String {
        self == .plainText ? "content-type.plain-text" : "content-type.\(rawValue)"
    }

    func localizedTitle(defaults: UserDefaults = .standard) -> String {
        L10n.string(localizationKey, defaults: defaults)
    }
}
