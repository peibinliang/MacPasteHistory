import Foundation

struct JWTContentAction: ContentAction {
    let id = ContentActionID(rawValue: "jwt.inspect")
    let titleKey = "jwt.inspect"; let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [.jwt, .plainText]
    func validate(input: String) -> ActionValidationResult { decoded(input) == nil ? .invalid(.parseFailed(messageKey: "content-action.jwt.invalid")) : .valid }
    func execute(input: String) throws -> ContentActionResult {
        guard let decoded = decoded(input) else { throw ContentActionError.parseFailed(messageKey: "content-action.jwt.invalid") }
        let header = String(data: decoded.0, encoding: .utf8)!
        let payload = String(data: decoded.1, encoding: .utf8)!
        return ContentActionResult(output: "\(header)\n\(payload)", syntax: .jwt, notices: [ContentActionNotice(messageKey: "content-action.jwt.signature-not-verified")], copyVariants: [ContentActionCopyVariant(id: "header", titleKey: "header", value: header), ContentActionCopyVariant(id: "payload", titleKey: "payload", value: payload), ContentActionCopyVariant(id: "summary", titleKey: "summary", value: input)])
    }
    private func decoded(_ input: String) -> (Data, Data)? {
        let parts = input.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let header = data(String(parts[0])), let payload = data(String(parts[1])), (try? JSONSerialization.jsonObject(with: header)) != nil, (try? JSONSerialization.jsonObject(with: payload)) != nil else { return nil }
        return (header, payload)
    }
    private func data(_ value: String) -> Data? { let normalized = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/"); return Data(base64Encoded: normalized + String(repeating: "=", count: (4 - normalized.count % 4) % 4)) }
}
