import Foundation

enum SearchTextMatchKind: Equatable {
    case exact
    case prefix
    case wholeWord
    case substring
    case fuzzy
}

struct SearchTextMatch: Equatable {
    let kind: SearchTextMatchKind
    let similarity: Double
}

struct SearchTextMatcher {
    private static let normalizedCharacterLimit = 4_096
    private static let fuzzyTokenLimit = 256
    private static let fuzzySimilarityThreshold = 0.60

    func match(term: String, in item: ClipboardHistoryItem) -> SearchTextMatch? {
        let normalizedTerm = normalize(term)
        guard normalizedTerm.isEmpty == false else { return nil }
        let normalizedText = normalize(item.searchableText ?? item.textContent)

        if normalizedText == normalizedTerm {
            return SearchTextMatch(kind: .exact, similarity: 1)
        }
        if normalizedText.hasPrefix(normalizedTerm) {
            return SearchTextMatch(kind: .prefix, similarity: 1)
        }
        let words = tokens(in: normalizedText)
        if words.contains(normalizedTerm) {
            return SearchTextMatch(kind: .wholeWord, similarity: 1)
        }
        if normalizedText.contains(normalizedTerm) {
            return SearchTextMatch(kind: .substring, similarity: 1)
        }
        return fuzzyMatch(term: normalizedTerm, normalizedText: normalizedText)
    }

    private func fuzzyMatch(term: String, normalizedText: String) -> SearchTextMatch? {
        let boundedText = String(normalizedText.prefix(Self.normalizedCharacterLimit))
        let lowerLength = Double(term.count) * 0.5
        let upperLength = Double(term.count) * 1.5
        let candidates = tokens(in: boundedText).prefix(Self.fuzzyTokenLimit).filter { token in
            let length = Double(token.count)
            return length >= lowerLength && length <= upperLength
        }
        guard let similarity = candidates.map({ normalizedSimilarity(term, $0) }).max(),
              similarity >= Self.fuzzySimilarityThreshold else {
            return nil
        }
        return SearchTextMatch(kind: .fuzzy, similarity: similarity)
    }

    private func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
    }

    private func tokens(in text: String) -> [String] {
        text.split { $0.isLetter == false && $0.isNumber == false }.map(String.init)
    }

    private func normalizedSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let maximumLength = max(lhs.count, rhs.count)
        guard maximumLength > 0 else { return 1 }
        return 1 - Double(levenshteinDistance(lhs, rhs)) / Double(maximumLength)
    }

    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)
        var previousRow = Array(0...rhsCharacters.count)

        for (lhsIndex, lhsCharacter) in lhsCharacters.enumerated() {
            var currentRow = [lhsIndex + 1]
            currentRow.reserveCapacity(rhsCharacters.count + 1)
            for (rhsIndex, rhsCharacter) in rhsCharacters.enumerated() {
                let substitutionCost = lhsCharacter == rhsCharacter ? 0 : 1
                currentRow.append(
                    min(
                        currentRow[rhsIndex] + 1,
                        previousRow[rhsIndex + 1] + 1,
                        previousRow[rhsIndex] + substitutionCost
                    )
                )
            }
            previousRow = currentRow
        }
        return previousRow[rhsCharacters.count]
    }
}
