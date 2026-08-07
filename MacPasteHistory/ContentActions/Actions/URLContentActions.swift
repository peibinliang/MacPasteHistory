import Foundation

struct URLContentAction: ContentAction {
    private static let queryValueAllowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    enum Kind: String { case encodeQueryValue = "encode-query-value", decode, extractHost = "extract-host", parseQuery = "parse-query" }
    let kind: Kind
    var id: ContentActionID { ContentActionID(rawValue: "url." + kind.rawValue) }
    var titleKey: String { id.rawValue }; var category: ContentActionCategory { .url }; var supportedTypes: Set<DetectedContentType> { [.url, .plainText] }
    func validate(input: String) -> ActionValidationResult {
        switch kind {
        case .decode:
            input.removingPercentEncoding == nil
                ? .invalid(.decodeFailed(messageKey: "content-action.url.invalid"))
                : .valid
        case .extractHost:
            URL(string: input)?.host == nil
                ? .invalid(.invalidInput(messageKey: "content-action.url.hostless"))
                : .valid
        case .parseQuery:
            URLComponents(string: input) == nil
                ? .invalid(.parseFailed(messageKey: "content-action.url.invalid"))
                : .valid
        case .encodeQueryValue:
            .valid
        }
    }
    func execute(input: String) throws -> ContentActionResult {
        let output: String
        switch kind {
        case .encodeQueryValue:
            output = input.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowedCharacters) ?? input
        case .decode:
            guard let decoded = input.removingPercentEncoding else {
                throw ContentActionError.decodeFailed(messageKey: "content-action.url.invalid")
            }
            output = decoded
        case .extractHost:
            guard let host = URL(string: input)?.host else { throw ContentActionError.invalidInput(messageKey: "content-action.url.hostless") }; output = host
        case .parseQuery:
            guard let components = URLComponents(string: input) else { throw ContentActionError.parseFailed(messageKey: "content-action.url.invalid") }
            let sortedItems = (components.queryItems ?? []).enumerated().sorted {
                $0.element.name == $1.element.name ? $0.offset < $1.offset : $0.element.name < $1.element.name
            }
            output = sortedItems.map { entry in
                "\(entry.element.name) = \(entry.element.value ?? "")"
            }.joined(separator: "\n")
        }
        return ContentActionResult(output: output, syntax: .plainText, notices: [], copyVariants: [])
    }
}
