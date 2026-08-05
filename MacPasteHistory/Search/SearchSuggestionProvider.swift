import Foundation

struct SearchSuggestion: Identifiable, Equatable {
    let title: String
    let replacement: String
    let replacementRange: Range<String.Index>

    var id: String { replacement }

    func applying(to input: String) -> SearchSuggestionAcceptance {
        var acceptedText = input
        acceptedText.replaceSubrange(replacementRange, with: replacement)
        let prefixLength = input.distance(from: input.startIndex, to: replacementRange.lowerBound)
        return SearchSuggestionAcceptance(text: acceptedText, cursorOffset: prefixLength + replacement.count)
    }
}

struct SearchSuggestionAcceptance: Equatable {
    let text: String
    let cursorOffset: Int
}

struct SearchSuggestionProvider {
    private static let maximumVisibleSuggestions = 10
    private let sourceOptions: [HistorySourceOption]

    init(sourceOptions: [HistorySourceOption]) {
        self.sourceOptions = sourceOptions
    }

    func suggestions(for input: String) -> [SearchSuggestion] {
        let activeRange = activeTokenRange(in: input)
        let activeText = String(input[activeRange])
        let normalizedText = activeText.lowercased()

        if ["a", "ap", "app"].contains(normalizedText) {
            return [suggestion(title: "app:", replacement: "app:", range: activeRange)]
        }
        if normalizedText.hasPrefix("type:") {
            return typeSuggestions(matching: String(normalizedText.dropFirst(5)), range: activeRange)
        }
        if normalizedText.hasPrefix("app:") {
            return sourceSuggestions(matching: String(normalizedText.dropFirst(4)), range: activeRange)
        }
        if normalizedText.hasPrefix("fav:") {
            return favoriteSuggestions(matching: String(normalizedText.dropFirst(4)), range: activeRange)
        }
        if normalizedText.hasPrefix("before:") {
            return dateSuggestions(prefix: "before:", range: activeRange)
        }
        if normalizedText.hasPrefix("after:") {
            return dateSuggestions(prefix: "after:", range: activeRange)
        }
        return []
    }

    private func typeSuggestions(matching value: String, range: Range<String.Index>) -> [SearchSuggestion] {
        Self.typeValues
            .filter { value.isEmpty || $0.value.hasPrefix(value) }
            .map { suggestion(title: $0.value, replacement: "type:\($0.value)", range: range) }
    }

    private func sourceSuggestions(matching value: String, range: Range<String.Index>) -> [SearchSuggestion] {
        sourceOptions
            .filter { option in
                value.isEmpty || option.title.lowercased().contains(value) || (option.bundleID?.lowercased().contains(value) ?? false)
            }
            .sorted { $0.title.caseInsensitiveCompare($1.title) == .orderedAscending }
            .prefix(Self.maximumVisibleSuggestions)
            .map { suggestion(title: $0.title, replacement: "app:\($0.title)", range: range) }
    }

    private func favoriteSuggestions(matching value: String, range: Range<String.Index>) -> [SearchSuggestion] {
        ["true", "false"]
            .filter { value.isEmpty || $0.hasPrefix(value) }
            .map { suggestion(title: $0, replacement: "fav:\($0)", range: range) }
    }

    private func dateSuggestions(prefix: String, range: Range<String.Index>) -> [SearchSuggestion] {
        ["1d", "7d", "30d", "YYYY-MM-DD"]
            .map { suggestion(title: $0, replacement: "\(prefix)\($0)", range: range) }
    }

    private func suggestion(title: String, replacement: String, range: Range<String.Index>) -> SearchSuggestion {
        SearchSuggestion(title: title, replacement: replacement, replacementRange: range)
    }

    private func activeTokenRange(in input: String) -> Range<String.Index> {
        var tokenStart = input.startIndex
        var index = input.startIndex
        var isQuoted = false
        var isEscaped = false

        while index < input.endIndex {
            let character = input[index]
            if isEscaped {
                isEscaped = false
            } else if isQuoted, character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                isQuoted.toggle()
            } else if isQuoted == false, character.isWhitespace {
                tokenStart = input.index(after: index)
            }
            index = input.index(after: index)
        }
        return tokenStart..<input.endIndex
    }

    private static let typeValues: [(value: String, type: DetectedContentType)] = [
        ("text", .plainText),
        ("image", .image),
        ("json", .json),
        ("url", .url),
        ("base64", .base64),
        ("jwt", .jwt),
        ("timestamp", .timestamp),
        ("sql", .sql),
        ("shell", .shell)
    ]
}
