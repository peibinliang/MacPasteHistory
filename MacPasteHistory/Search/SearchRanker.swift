import Foundation

struct RankedSearchResult: Identifiable, Equatable {
    let item: ClipboardHistoryItem
    let score: Double
    let matchedTerms: [String]

    var id: Int64 { item.id }
}

struct SearchRanker {
    private let matcher: SearchTextMatcher
    private let weights: SearchRankingWeights
    private let now: () -> Date

    init(
        matcher: SearchTextMatcher = SearchTextMatcher(),
        weights: SearchRankingWeights = SearchRankingWeights(),
        now: @escaping () -> Date = Date.init
    ) {
        self.matcher = matcher
        self.weights = weights
        self.now = now
    }

    func rank(items: [ClipboardHistoryItem], terms: [String]) -> [RankedSearchResult] {
        let normalizedTerms = terms.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        return items.compactMap { item in
            rank(item: item, terms: normalizedTerms)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.item.id > rhs.item.id
            }
            return lhs.score > rhs.score
        }
    }

    private func rank(item: ClipboardHistoryItem, terms: [String]) -> RankedSearchResult? {
        let matches = terms.compactMap { matcher.match(term: $0, in: item) }
        guard terms.isEmpty || matches.count == terms.count else { return nil }

        var score = matches.reduce(0) { partialResult, match in
            partialResult + textScore(for: match)
        }
        if terms.count > 1 {
            score += weights.allTermsBonus
        }
        score += recencyScore(for: item.lastCapturedAt ?? item.createdAt, maximum: weights.captureRecencyMaximum, halfLife: 7 * 86_400)
        if let lastPastedAt = item.lastPastedAt {
            score += recencyScore(for: lastPastedAt, maximum: weights.pasteRecencyMaximum, halfLife: 14 * 86_400)
        }
        score += countScore(item.pasteCount, maximum: weights.pasteCountMaximum)
        score += countScore(item.reuseCopyCount, maximum: weights.reuseCopyCountMaximum)
        if item.isFavorite {
            score += weights.favorite
        }
        if sourceMatches(terms, item: item) {
            score += weights.sourceMaximum
        }

        return RankedSearchResult(item: item, score: score, matchedTerms: terms)
    }

    private func textScore(for match: SearchTextMatch) -> Double {
        switch match.kind {
        case .exact:
            return weights.exact
        case .prefix:
            return weights.prefix
        case .wholeWord:
            return weights.wholeWord
        case .substring:
            return weights.substring
        case .fuzzy:
            return weights.fuzzyMaximum * match.similarity
        }
    }

    private func recencyScore(for date: Date, maximum: Double, halfLife: TimeInterval) -> Double {
        let age = max(0, now().timeIntervalSince(date))
        return maximum * pow(0.5, age / halfLife)
    }

    private func countScore(_ count: Int, maximum: Double) -> Double {
        let nonNegativeCount = max(0, count)
        return min(maximum, log2(Double(nonNegativeCount) + 1) / log2(65) * maximum)
    }

    private func sourceMatches(_ terms: [String], item: ClipboardHistoryItem) -> Bool {
        guard terms.isEmpty == false else { return false }
        let source = [item.sourceApp, item.sourceBundleID].compactMap { $0 }.joined(separator: " ").lowercased()
        return terms.contains { term in source.contains(term.lowercased()) }
    }
}
