import Foundation

enum SensitiveContentCategory: String, Equatable, Sendable {
    case none
    case credential
    case bankCard
    case identity
    case secret
    case userRule
}

enum SensitiveDetectionConfidence: String, Equatable, Sendable {
    case none
    case low
    case medium
    case high
}

enum SensitiveDetectionReason: String, Equatable, Sendable {
    case noMatch = "no_match"
    case credentialAssignment = "credential_assignment"
    case authorizationHeader = "authorization_header"
    case validatedCardChecksum = "validated_card_checksum"
    case validatedIdentityChecksum = "validated_identity_checksum"
    case contextualSecret = "contextual_secret"
    case userRuleMatch = "user_rule_match"
}

struct SensitiveDetectionResult: Equatable, Sendable {
    let category: SensitiveContentCategory
    let confidence: SensitiveDetectionConfidence
    let reason: SensitiveDetectionReason

    static let none = SensitiveDetectionResult(
        category: .none,
        confidence: .none,
        reason: .noMatch
    )

    var shouldBlockPersistence: Bool {
        category != .none && confidence == .high
    }
}

protocol SensitiveContentRule {
    func match(in text: String) -> SensitiveDetectionResult?
}

struct SensitiveContentDetector {
    private let rules: [any SensitiveContentRule]

    init(additionalRules: [any SensitiveContentRule] = []) {
        rules = [
            CredentialSensitiveContentRule(),
            IdentitySensitiveContentRule(),
            BankCardSensitiveContentRule(),
            ContextualSecretContentRule()
        ] + additionalRules
    }

    func result(for text: String) -> SensitiveDetectionResult {
        for rule in rules {
            if let result = rule.match(in: text) {
                return result
            }
        }
        return .none
    }

    static func detect(_ text: String) -> SensitiveDetectionResult {
        SensitiveContentDetector().result(for: text)
    }

    static func isSensitive(_ text: String) -> Bool {
        detect(text).shouldBlockPersistence
    }
}

/// Extension boundary for future user-defined local rules. The inspected text and matched value are never retained.
struct UserSensitiveContentRule: SensitiveContentRule {
    private let regex: NSRegularExpression
    private let confidence: SensitiveDetectionConfidence

    init(pattern: String, confidence: SensitiveDetectionConfidence = .high) throws {
        regex = try NSRegularExpression(pattern: pattern)
        self.confidence = confidence
    }

    func match(in text: String) -> SensitiveDetectionResult? {
        guard regex.hasMatch(in: text) else { return nil }
        return SensitiveDetectionResult(
            category: .userRule,
            confidence: confidence,
            reason: .userRuleMatch
        )
    }
}

private struct CredentialSensitiveContentRule: SensitiveContentRule {
    private let assignmentRegex = try? NSRegularExpression(
        pattern: #"(?i)\b(password|passwd|pwd|api[_-]?key|access[_-]?token)\b\s*[:=]\s*["']?\S+"#
    )
    private let authorizationRegex = try? NSRegularExpression(
        pattern: #"(?i)(\bauthorization\s*:\s*)?\b(bearer|basic)\s+[A-Za-z0-9+/_=.\-]{20,}"#
    )

    func match(in text: String) -> SensitiveDetectionResult? {
        if assignmentRegex?.hasMatch(in: text) == true {
            return SensitiveDetectionResult(
                category: .credential,
                confidence: .high,
                reason: .credentialAssignment
            )
        }
        if authorizationRegex?.hasMatch(in: text) == true {
            return SensitiveDetectionResult(
                category: .credential,
                confidence: .high,
                reason: .authorizationHeader
            )
        }
        return nil
    }
}

private struct ContextualSecretContentRule: SensitiveContentRule {
    private let regex = try? NSRegularExpression(
        pattern: #"(?i)\b(secret(?:[_-]?key)?|client[_-]?secret)\b\s*[:=]\s*["']?\S+"#
    )

    func match(in text: String) -> SensitiveDetectionResult? {
        guard regex?.hasMatch(in: text) == true else { return nil }
        return SensitiveDetectionResult(
            category: .secret,
            confidence: .high,
            reason: .contextualSecret
        )
    }
}

private struct BankCardSensitiveContentRule: SensitiveContentRule {
    private let candidateRegex = try? NSRegularExpression(
        pattern: #"(?<!\d)(?:\d[ -]?){15,18}\d(?!\d)"#
    )

    func match(in text: String) -> SensitiveDetectionResult? {
        guard let candidateRegex else { return nil }
        for candidate in candidateRegex.matches(in: text) {
            let digits = candidate.filter(\.isNumber)
            if (16...19).contains(digits.count), digits.passesLuhnChecksum {
                return SensitiveDetectionResult(
                    category: .bankCard,
                    confidence: .high,
                    reason: .validatedCardChecksum
                )
            }
        }
        return nil
    }
}

private struct IdentitySensitiveContentRule: SensitiveContentRule {
    private let candidateRegex = try? NSRegularExpression(
        pattern: #"(?<![0-9A-Za-z])\d{17}[\dXx](?![0-9A-Za-z])"#
    )

    func match(in text: String) -> SensitiveDetectionResult? {
        guard let candidateRegex else { return nil }
        for candidate in candidateRegex.matches(in: text) where candidate.isValidMainlandIdentityNumber {
            return SensitiveDetectionResult(
                category: .identity,
                confidence: .high,
                reason: .validatedIdentityChecksum
            )
        }
        return nil
    }
}

private extension NSRegularExpression {
    func hasMatch(in text: String) -> Bool {
        firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    func matches(in text: String) -> [String] {
        matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}

private extension String {
    var passesLuhnChecksum: Bool {
        let digits = compactMap(\.wholeNumberValue)
        guard digits.count == count else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { partial, item in
            let (offset, digit) = item
            if offset.isMultiple(of: 2) {
                return partial + digit
            }
            let doubled = digit * 2
            return partial + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum.isMultiple(of: 10)
    }

    var isValidMainlandIdentityNumber: Bool {
        let normalized = uppercased()
        guard normalized.count == 18 else { return false }

        let characters = Array(normalized)
        guard characters.prefix(17).allSatisfy(\.isNumber) else { return false }
        guard hasValidIdentityBirthDate(normalized) else { return false }

        let weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
        let checkCharacters = Array("10X98765432")
        let weightedSum = zip(characters.prefix(17), weights).reduce(0) { partial, pair in
            partial + (pair.0.wholeNumberValue ?? 0) * pair.1
        }
        return characters[17] == checkCharacters[weightedSum % 11]
    }

    private func hasValidIdentityBirthDate(_ identity: String) -> Bool {
        let characters = Array(identity)
        guard let year = Int(String(characters[6...9])),
              let month = Int(String(characters[10...11])),
              let day = Int(String(characters[12...13])) else {
            return false
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return false
        }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return components.year == year && components.month == month && components.day == day
    }
}
