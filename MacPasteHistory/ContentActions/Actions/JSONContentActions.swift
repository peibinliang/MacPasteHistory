import Foundation

struct JSONContentAction: ContentAction {
    enum Kind: String { case format, minify, validate, escape, unescape }
    let kind: Kind
    var id: ContentActionID { ContentActionID(rawValue: "json." + kind.rawValue) }
    var titleKey: String { id.rawValue }
    var category: ContentActionCategory { .json }
    var supportedTypes: Set<DetectedContentType> { [.json, .plainText] }
    func validate(input: String) -> ActionValidationResult {
        let isValid: Bool
        switch kind {
        case .escape:
            isValid = true
        case .unescape:
            isValid = (try? unescaped(input)) != nil
        case .format, .minify, .validate:
            isValid = (try? normalized(input)) != nil
        }
        return isValid ? .valid : .invalid(.parseFailed(messageKey: "content-action.json.invalid"))
    }
    func execute(input: String) throws -> ContentActionResult {
        let output: String
        switch kind {
        case .format: output = fourSpaceIndented(try normalized(input, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]))
        case .minify, .validate: output = try normalized(input)
        case .escape:
            let encoded = try JSONSerialization.data(withJSONObject: input, options: [.fragmentsAllowed, .withoutEscapingSlashes])
            guard let quoted = String(data: encoded, encoding: .utf8) else {
                throw ContentActionError.parseFailed(messageKey: "content-action.json.invalid")
            }
            output = String(quoted.dropFirst().dropLast())
        case .unescape:
            output = try unescaped(input)
        }
        return ContentActionResult(output: output, syntax: .json, notices: kind == .validate ? [ContentActionNotice(messageKey: "content-action.json.valid")] : [], copyVariants: [])
    }
    private func normalized(_ input: String, options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]) throws -> String {
        guard let data = input.data(using: .utf8) else { throw ContentActionError.invalidInput(messageKey: "content-action.json.invalid") }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let result = String(data: try JSONSerialization.data(withJSONObject: object, options: options), encoding: .utf8) else { throw ContentActionError.parseFailed(messageKey: "content-action.json.invalid") }
        return result
    }

    private func unescaped(_ input: String) throws -> String {
        let quoted = input.hasPrefix("\"") ? input : "\"\(input)\""
        guard let value = try JSONSerialization.jsonObject(
            with: Data(quoted.utf8),
            options: .fragmentsAllowed
        ) as? String else {
            throw ContentActionError.parseFailed(messageKey: "content-action.json.invalid")
        }
        return value
    }

    private func fourSpaceIndented(_ input: String) -> String {
        input.components(separatedBy: "\n").map { line in
            let indentation = line.prefix { $0 == " " }.count
            return String(repeating: " ", count: indentation * 2) + String(line.dropFirst(indentation))
        }.joined(separator: "\n")
    }
}
