import Foundation

struct SearchQueryParser {
    private let calendar: Calendar
    private let now: () -> Date

    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
    }

    func parse(_ input: String) -> ParsedSearchQuery {
        var terms: [String] = []
        var tokens: [SearchToken] = []
        var issues: [SearchParseIssue] = []
        var app: String?
        var type: DetectedContentType?
        var favorite: Bool?
        var before: Date?
        var after: Date?
        let referenceDate = now()

        for lexeme in tokenize(input) {
            if lexeme.hasUnterminatedQuote {
                terms.append(lexeme.value)
                issues.append(SearchParseIssue(kind: .unterminatedQuote, range: lexeme.range))
                continue
            }
            guard let prefixAndValue = knownPrefixAndValue(in: lexeme.value) else {
                terms.append(lexeme.value)
                continue
            }

            if let tokenKind = parsedToken(for: prefixAndValue, referenceDate: referenceDate) {
                tokens.removeAll { $0.kind.dimension == tokenKind.dimension }
                tokens.append(SearchToken(kind: tokenKind, range: lexeme.range))
                switch tokenKind {
                case let .app(value):
                    app = value
                case let .type(value):
                    type = value
                case let .favorite(value):
                    favorite = value
                case let .before(value):
                    before = value
                case let .after(value):
                    after = value
                case .invalid:
                    break
                }
            } else {
                let token = SearchToken(
                    kind: .invalid(prefix: prefixAndValue.prefix, value: prefixAndValue.value),
                    range: lexeme.range
                )
                tokens.append(token)
                issues.append(SearchParseIssue(kind: .invalidValue, range: lexeme.range))
            }
        }

        return ParsedSearchQuery(
            rawInput: input,
            terms: terms,
            app: app,
            type: type,
            favorite: favorite,
            before: before,
            after: after,
            tokens: tokens,
            issues: issues
        )
    }

    private func parsedToken(
        for prefixAndValue: PrefixAndValue,
        referenceDate: Date
    ) -> SearchTokenKind? {
        switch prefixAndValue.prefix {
        case "app":
            guard prefixAndValue.value.isEmpty == false else { return nil }
            return .app(prefixAndValue.value)
        case "type":
            guard let type = Self.detectedType(for: prefixAndValue.value) else { return nil }
            return .type(type)
        case "fav":
            switch prefixAndValue.value.lowercased() {
            case "true":
                return .favorite(true)
            case "false":
                return .favorite(false)
            default:
                return nil
            }
        case "before":
            guard let date = parseDate(prefixAndValue.value, referenceDate: referenceDate) else { return nil }
            return .before(date)
        case "after":
            guard let date = parseDate(prefixAndValue.value, referenceDate: referenceDate) else { return nil }
            return .after(date)
        default:
            return nil
        }
    }

    private func parseDate(_ value: String, referenceDate: Date) -> Date? {
        if value.last?.lowercased() == "d", let dayCount = Int(value.dropLast()), dayCount >= 0 {
            return calendar.date(byAdding: .day, value: -dayCount, to: referenceDate)
        }

        let components = value.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return nil
        }
        let parsedComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard parsedComponents.year == year, parsedComponents.month == month, parsedComponents.day == day else {
            return nil
        }
        return date
    }

    private func knownPrefixAndValue(in value: String) -> PrefixAndValue? {
        guard let separator = value.firstIndex(of: ":") else {
            return nil
        }
        let prefix = String(value[..<separator]).lowercased()
        guard ["app", "type", "fav", "before", "after"].contains(prefix) else {
            return nil
        }
        return PrefixAndValue(prefix: prefix, value: String(value[value.index(after: separator)...]))
    }

    private func tokenize(_ input: String) -> [SearchLexeme] {
        var lexemes: [SearchLexeme] = []
        var index = input.startIndex

        while index < input.endIndex {
            while index < input.endIndex, input[index].isWhitespace {
                index = input.index(after: index)
            }
            guard index < input.endIndex else { break }

            let start = index
            var value = ""
            var isQuoted = false
            var hasUnterminatedQuote = false

            while index < input.endIndex {
                let character = input[index]
                if isQuoted {
                    if character == "\\" {
                        let nextIndex = input.index(after: index)
                        guard nextIndex < input.endIndex else {
                            value.append(character)
                            index = nextIndex
                            continue
                        }
                        let nextCharacter = input[nextIndex]
                        if nextCharacter == "\\" || nextCharacter == "\"" {
                            value.append(nextCharacter)
                        } else {
                            value.append(character)
                            value.append(nextCharacter)
                        }
                        index = input.index(after: nextIndex)
                    } else if character == "\"" {
                        isQuoted = false
                        index = input.index(after: index)
                    } else {
                        value.append(character)
                        index = input.index(after: index)
                    }
                    continue
                }

                if character.isWhitespace {
                    break
                }
                if character == "\"" {
                    isQuoted = true
                    hasUnterminatedQuote = true
                    index = input.index(after: index)
                    continue
                }
                value.append(character)
                index = input.index(after: index)
            }

            if isQuoted == false {
                hasUnterminatedQuote = false
            }
            lexemes.append(SearchLexeme(value: value, range: start..<index, hasUnterminatedQuote: hasUnterminatedQuote))
        }
        return lexemes
    }

    private static func detectedType(for value: String) -> DetectedContentType? {
        switch value.lowercased() {
        case "text", "plaintext":
            return .plainText
        default:
            return DetectedContentType.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
        }
    }
}

private struct PrefixAndValue {
    let prefix: String
    let value: String
}

private struct SearchLexeme {
    let value: String
    let range: Range<String.Index>
    let hasUnterminatedQuote: Bool
}
