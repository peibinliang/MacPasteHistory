import Foundation

struct JWTContentAction: ContentAction {
    let id = ContentActionID(rawValue: "jwt.inspect")
    let titleKey = "jwt.inspect"
    let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [.jwt, .plainText]

    func validate(input: String) -> ActionValidationResult {
        decoded(input) == nil
            ? .invalid(.parseFailed(messageKey: "content-action.jwt.invalid"))
            : .valid
    }

    func execute(input: String) throws -> ContentActionResult {
        guard let decoded = decoded(input) else {
            throw ContentActionError.parseFailed(messageKey: "content-action.jwt.invalid")
        }

        let header = try formattedJSON(decoded.headerObject)
        let payload = try formattedJSON(decoded.payloadObject)
        let claims = claimSummary(header: decoded.headerObject, payload: decoded.payloadObject)
        let output = [
            "Header",
            header,
            "Payload",
            payload,
            "Claims",
            claims
        ].joined(separator: "\n")

        return ContentActionResult(
            output: output,
            syntax: .jwt,
            notices: [
                ContentActionNotice(messageKey: "content-action.jwt.signature-not-verified"),
                ContentActionNotice(messageKey: expirationNoticeKey(payload: decoded.payloadObject))
            ],
            copyVariants: [
                ContentActionCopyVariant(id: "header", titleKey: "header", value: header),
                ContentActionCopyVariant(id: "payload", titleKey: "payload", value: payload),
                ContentActionCopyVariant(id: "summary", titleKey: "summary", value: output)
            ]
        )
    }

    private func decoded(_ input: String) -> (headerObject: [String: Any], payloadObject: [String: Any])? {
        let parts = input.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let headerData = data(String(parts[0])),
              let payloadData = data(String(parts[1])),
              let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }
        return (header, payload)
    }

    private func data(_ value: String) -> Data? {
        let normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        return Data(base64Encoded: normalized + String(repeating: "=", count: (4 - normalized.count % 4) % 4))
    }

    private func formattedJSON(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        guard let text = String(data: data, encoding: .utf8) else {
            throw ContentActionError.parseFailed(messageKey: "content-action.jwt.invalid")
        }
        return text.components(separatedBy: "\n").map { line in
            let indentation = line.prefix { $0 == " " }.count
            return String(repeating: " ", count: indentation * 2) + String(line.dropFirst(indentation))
        }.joined(separator: "\n")
    }

    private func claimSummary(header: [String: Any], payload: [String: Any]) -> String {
        var lines: [String] = []
        for (name, source) in [("alg", header), ("typ", header), ("iss", payload), ("sub", payload), ("aud", payload)] {
            if let value = source[name] {
                lines.append("\(name) = \(displayValue(value))")
            }
        }
        for name in ["iat", "exp", "nbf"] {
            guard let timestamp = numericDate(payload[name]),
                  let result = try? TimestampContentAction().execute(input: String(Int64(timestamp))) else {
                continue
            }
            for variant in result.copyVariants where ["local", "utc", "iso8601"].contains(variant.id) {
                lines.append("\(name).\(variant.id) = \(variant.value)")
            }
        }
        return lines.isEmpty ? "-" : lines.joined(separator: "\n")
    }

    private func displayValue(_ value: Any) -> String {
        if let strings = value as? [String] { return strings.joined(separator: ", ") }
        return String(describing: value)
    }

    private func numericDate(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private func expirationNoticeKey(payload: [String: Any]) -> String {
        guard let expiration = numericDate(payload["exp"]) else {
            return "content-action.jwt.no-expiration"
        }
        return expiration < Date().timeIntervalSince1970
            ? "content-action.jwt.expired"
            : "content-action.jwt.not-expired"
    }
}
