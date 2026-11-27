import Foundation

struct ContentClassifier: Sendable {
    static let currentVersion = 1

    private static let base64Regex = try? NSRegularExpression(pattern: "^[A-Za-z0-9+/]*={0,2}$")
    private static let shellEnvCommandRegex = try? NSRegularExpression(
        pattern: #"(?m)(?:^|\s)[A-Za-z_][A-Za-z0-9_]*+=\S*+\s++\S+"#
    )
    private static let shellFlagRegex = try? NSRegularExpression(
        pattern: #"(?:^|\s)\S++\s++--?\w+"#
    )
    private static let maxJSONInspectionBytes = 512 * 1024

    func classifyFast(_ input: String, at date: Date = Date()) -> ContentDetectionResult {
        let value = boundedInspectionSlice(of: input)
        let type: DetectedContentType
        if isJWT(value) { type = .jwt }
        else if isJSON(input, trimmedPreview: value) { type = .json }
        else if isURL(value) { type = .url }
        else if isTimestamp(value) { type = .timestamp }
        else if isBase64(value) { type = .base64 }
        else { type = .plainText }
        return ContentDetectionResult(type: type, confidence: type == .plainText ? 0.5 : 0.95, version: Self.currentVersion, detectedAt: date)
    }

    func classifyComplete(_ input: String, at date: Date = Date()) -> ContentDetectionResult {
        let fast = classifyFast(input, at: date)
        guard fast.type == .plainText else { return fast }
        let value = boundedInspectionSlice(of: input)
        let type: DetectedContentType
        if isSQL(value) { type = .sql }
        else if isShell(value) { type = .shell }
        else { type = .plainText }
        return ContentDetectionResult(type: type, confidence: type == .plainText ? fast.confidence : 0.9, version: Self.currentVersion, detectedAt: date)
    }

    private func boundedInspectionSlice(of input: String) -> String {
        let limit = DefaultSettings.classificationMaxInspectionCharacters
        let slice = input.utf8.count > limit ? String(input.prefix(limit)) : input
        return slice.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isJWT(_ value: String) -> Bool {
        guard value.utf8.count <= 16_384 else { return false }
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ $0.isEmpty == false }),
              let header = decodeBase64URL(String(parts[0])), let payload = decodeBase64URL(String(parts[1])) else { return false }
        return isJSONData(header) && isJSONData(payload)
    }

    private func isJSON(_ rawInput: String, trimmedPreview: String) -> Bool {
        guard trimmedPreview.first == "{" || trimmedPreview.first == "[",
              rawInput.utf8.count <= Self.maxJSONInspectionBytes else {
            return false
        }
        let candidate = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = candidate.data(using: .utf8) else { return false }
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
        guard value.count >= 8, value.utf8.count <= DefaultSettings.classificationMaxInspectionCharacters,
              value.count % 4 == 0,
              let regex = Self.base64Regex,
              regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil,
              let data = Data(base64Encoded: value),
              let decoded = String(data: data, encoding: .utf8),
              decoded.isEmpty == false else {
            return false
        }
        let printable = decoded.unicodeScalars.filter {
            $0.properties.isWhitespace || CharacterSet.controlCharacters.contains($0) == false
        }.count
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
        if value.contains("|") || value.contains(">") {
            return true
        }
        let range = NSRange(value.startIndex..., in: value)
        if Self.shellEnvCommandRegex?.firstMatch(in: value, range: range) != nil {
            return true
        }
        return Self.shellFlagRegex?.firstMatch(in: value, range: range) != nil
    }
}
