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
        let header = try formattedJSON(decoded.header)
        let payload = try formattedJSON(decoded.payload)
        let claims = claimSummary(header: decoded.header, payload: decoded.payload)
        let sections = ["Header:", header, "", "Payload:", payload, "", "Claims:", claims]
        let output = sections.joined(separator: "\n")
        return ContentActionResult(
            output: output,
            syntax: .jwt,
            notices: [
                ContentActionNotice(messageKey: "content-action.jwt.signature-not-verified"),
                ContentActionNotice(messageKey: expirationNotice(payload: decoded.payload))
            ],
            copyVariants: [
                ContentActionCopyVariant(id: "header", titleKey: "header", value: header),
                ContentActionCopyVariant(id: "payload", titleKey: "payload", value: payload),
                ContentActionCopyVariant(id: "summary", titleKey: "summary", value: output)
            ]
        )
    }

    private func decoded(_ input: String) -> (header: [String: Any], payload: [String: Any])? {
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
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        guard let pretty = String(data: data, encoding: .utf8) else {
            throw ContentActionError.parseFailed(messageKey: "content-action.jwt.invalid")
        }
        return pretty.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let indentation = line.prefix { $0 == " " }.count
            return String(repeating: " ", count: indentation * 2) + String(line.dropFirst(indentation))
        }.joined(separator: "\n")
    }

    private func claimSummary(header: [String: Any], payload: [String: Any]) -> String {
        var lines: [String] = []
        for key in ["alg", "typ"] {
            if let value = displayValue(header[key]) { lines.append("\(key) = \(value)") }
        }
        for key in ["iss", "sub", "aud"] {
            if let value = displayValue(payload[key]) { lines.append("\(key) = \(value)") }
        }
        for key in ["iat", "exp", "nbf"] {
            guard let seconds = numericDate(payload[key]) else { continue }
            let date = Date(timeIntervalSince1970: seconds)
            lines.append("\(key).local = \(dateString(date, timeZone: .current, suffix: nil))")
            lines.append("\(key).utc = \(dateString(date, timeZone: TimeZone(secondsFromGMT: 0)!, suffix: "UTC"))")
            lines.append("\(key).iso8601 = \(ISO8601DateFormatter().string(from: date))")
        }
        return lines.isEmpty ? "—" : lines.joined(separator: "\n")
    }

    private func displayValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let string = value as? String { return string }
        if JSONSerialization.isValidJSONObject([value]),
           let data = try? JSONSerialization.data(withJSONObject: value),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: value)
    }

    private func numericDate(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private func expirationNotice(payload: [String: Any]) -> String {
        guard let seconds = numericDate(payload["exp"]) else {
            return "content-action.jwt.no-expiration"
        }
        return Date(timeIntervalSince1970: seconds) <= Date()
            ? "content-action.jwt.expired"
            : "content-action.jwt.not-expired"
    }

    private func dateString(_ date: Date, timeZone: TimeZone, suffix: String?) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = suffix == nil ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd HH:mm:ss 'UTC'"
        return formatter.string(from: date)
    }
}
