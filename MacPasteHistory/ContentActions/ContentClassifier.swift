import Foundation

struct ContentClassifier {
    static let currentVersion = 1

    func classifyFast(_ input: String, at date: Date = Date()) -> ContentDetectionResult {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let type: DetectedContentType
        if isJWT(value) { type = .jwt }
        else if isJSON(value) { type = .json }
        else if isURL(value) { type = .url }
        else if isTimestamp(value) { type = .timestamp }
        else if isBase64(value) { type = .base64 }
        else { type = .plainText }
        return ContentDetectionResult(type: type, confidence: type == .plainText ? 0.5 : 0.95, version: Self.currentVersion, detectedAt: date)
    }

    func classifyComplete(_ input: String, at date: Date = Date()) -> ContentDetectionResult {
        let fast = classifyFast(input, at: date)
        guard fast.type == .plainText else { return fast }
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let type: DetectedContentType
        if isSQL(value) { type = .sql }
        else if isShell(value) { type = .shell }
        else { type = .plainText }
        return ContentDetectionResult(type: type, confidence: type == .plainText ? fast.confidence : 0.9, version: Self.currentVersion, detectedAt: date)
    }

    private func isJWT(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ $0.isEmpty == false }),
              let header = decodeBase64URL(String(parts[0])), let payload = decodeBase64URL(String(parts[1])) else { return false }
        return isJSONData(header) && isJSONData(payload)
    }

    private func isJSON(_ value: String) -> Bool {
        guard value.first == "{" || value.first == "[", let data = value.data(using: .utf8) else { return false }
        return isJSONData(data)
    }

    private func isJSONData(_ data: Data) -> Bool {
        (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private func isURL(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "file", "ssh", "git"].contains(scheme) && (scheme == "file" || url.host != nil || value.contains(":"))
    }

    private func isTimestamp(_ value: String) -> Bool {
        guard value.allSatisfy(\.isNumber), value.count == 10 || value.count == 13,
              let seconds = Double(value).map({ value.count == 13 ? $0 / 1_000 : $0 }) else { return false }
        let calendar = Calendar(identifier: .gregorian)
        guard let lower = calendar.date(from: DateComponents(year: 2000)), let upper = calendar.date(from: DateComponents(year: 2100)) else { return false }
        return Date(timeIntervalSince1970: seconds) >= lower && Date(timeIntervalSince1970: seconds) <= upper
    }

    private func isBase64(_ value: String) -> Bool {
        guard value.count >= 8, value.range(of: "^[A-Za-z0-9+/]*={0,2}$", options: .regularExpression) != nil,
              value.count % 4 == 0, let data = Data(base64Encoded: value), let decoded = String(data: data, encoding: .utf8), decoded.isEmpty == false else { return false }
        let printable = decoded.unicodeScalars.filter { $0.properties.isWhitespace || $0.value >= 32 && $0.value < 127 }.count
        return Double(printable) / Double(decoded.unicodeScalars.count) >= 0.85
    }

    private func decodeBase64URL(_ value: String) -> Data? {
        let normalized = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        return Data(base64Encoded: normalized + String(repeating: "=", count: (4 - normalized.count % 4) % 4))
    }

    private func isSQL(_ value: String) -> Bool {
        let upper = value.uppercased()
        return (upper.hasPrefix("SELECT ") && upper.contains(" FROM ")) || (upper.hasPrefix("UPDATE ") && upper.contains(" SET "))
    }

    private func isShell(_ value: String) -> Bool {
        value.contains("|") || value.contains(">") || value.range(of: "\\b[a-zA-Z_][a-zA-Z0-9_]*=.*\\s+\\S+", options: .regularExpression) != nil || value.range(of: "\\S+\\s+--?\\w+", options: .regularExpression) != nil
    }
}
