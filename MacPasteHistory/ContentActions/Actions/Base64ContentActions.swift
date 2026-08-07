import Foundation

struct Base64ContentAction: BinaryContentAction {
    enum Kind: String { case encode, decode, decodeURLSafe = "decode-url-safe", validate }
    let kind: Kind
    var id: ContentActionID { ContentActionID(rawValue: "base64." + kind.rawValue) }
    var titleKey: String { id.rawValue }; var category: ContentActionCategory { .base64 }
    var supportedTypes: Set<DetectedContentType> {
        kind == .encode ? [.base64, .plainText, .image] : [.base64, .plainText]
    }
    func validate(input: String) -> ActionValidationResult {
        guard kind != .encode else { return .valid }
        return data(input, urlSafe: kind == .decodeURLSafe) == nil
            ? .invalid(.decodeFailed(messageKey: "content-action.base64.invalid"))
            : .valid
    }
    func execute(input: String) throws -> ContentActionResult {
        if kind == .encode { return ContentActionResult(output: Data(input.utf8).base64EncodedString(), syntax: .plainText, notices: [], copyVariants: []) }
        guard let result = data(input, urlSafe: kind == .decodeURLSafe) else { throw ContentActionError.decodeFailed(messageKey: "content-action.base64.invalid") }
        if kind == .validate {
            return ContentActionResult(output: input, syntax: .plainText, notices: [ContentActionNotice(messageKey: "content-action.base64.valid")], copyVariants: [])
        }
        guard let output = String(data: result, encoding: .utf8), isMostlyPrintable(output) else {
            throw ContentActionError.nonUTF8Result(messageKey: "content-action.base64.non-utf8")
        }
        return ContentActionResult(output: output, syntax: .plainText, notices: [], copyVariants: [])
    }
    func execute(data: Data) throws -> ContentActionResult {
        guard kind == .encode else {
            throw ContentActionError.unsupportedInput(messageKey: "content-action.unsupported")
        }
        return ContentActionResult(output: data.base64EncodedString(), syntax: .plainText, notices: [], copyVariants: [])
    }
    private func data(_ input: String, urlSafe: Bool) -> Data? { let value = urlSafe ? input.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") : input; return Data(base64Encoded: value + String(repeating: "=", count: (4 - value.count % 4) % 4)) }

    private func isMostlyPrintable(_ value: String) -> Bool {
        let scalars = value.unicodeScalars
        guard scalars.isEmpty == false else { return true }
        let nonPrintableCount = scalars.reduce(into: 0) { count, scalar in
            if CharacterSet.controlCharacters.contains(scalar), "\n\r\t".unicodeScalars.contains(scalar) == false {
                count += 1
            }
        }
        return Double(nonPrintableCount) / Double(scalars.count) <= 0.2
    }
}
