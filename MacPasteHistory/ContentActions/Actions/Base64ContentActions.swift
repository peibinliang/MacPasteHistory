import Foundation

struct Base64ContentAction: ContentAction {
    enum Kind: String { case encode, decode, decodeURLSafe = "decode-url-safe", validate }
    let kind: Kind
    var id: ContentActionID { ContentActionID(rawValue: "base64." + kind.rawValue) }
    var titleKey: String { id.rawValue }; var category: ContentActionCategory { .base64 }; var supportedTypes: Set<DetectedContentType> { [.base64, .plainText] }
    func validate(input: String) -> ActionValidationResult { data(input, urlSafe: kind == .decodeURLSafe) == nil ? .invalid(.decodeFailed(messageKey: "content-action.base64.invalid")) : .valid }
    func execute(input: String) throws -> ContentActionResult {
        if kind == .encode { return ContentActionResult(output: Data(input.utf8).base64EncodedString(), syntax: .plainText, notices: [], copyVariants: []) }
        guard let result = data(input, urlSafe: kind == .decodeURLSafe) else { throw ContentActionError.decodeFailed(messageKey: "content-action.base64.invalid") }
        guard let output = String(data: result, encoding: .utf8) else { throw ContentActionError.nonUTF8Result(messageKey: "content-action.base64.non-utf8") }
        return ContentActionResult(output: kind == .validate ? input : output, syntax: .plainText, notices: kind == .validate ? [ContentActionNotice(messageKey: "content-action.base64.valid")] : [], copyVariants: [])
    }
    private func data(_ input: String, urlSafe: Bool) -> Data? { let value = urlSafe ? input.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") : input; return Data(base64Encoded: value + String(repeating: "=", count: (4 - value.count % 4) % 4)) }
}
