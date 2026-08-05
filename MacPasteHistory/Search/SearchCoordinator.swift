import Foundation

protocol SearchCoordinating: Sendable {
    func immediateResults(input: String, loadedItems: [ClipboardHistoryItem], filters: SearchUIFilters) async -> SearchResponse
    func search(input: String, loadedItems: [ClipboardHistoryItem], filters: SearchUIFilters) async -> SearchResponse
    func cancelCurrentSearch() async
}

protocol SearchSleeping: Sendable {
    func sleep(for delay: TimeInterval) async throws
}

struct SearchResponse: Equatable {
    let parsedQuery: ParsedSearchQuery
    let results: [RankedSearchResult]
    let isCurrent: Bool
    let errorDescription: String?
}

struct DefaultSearchSleeper: SearchSleeping {
    func sleep(for delay: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(delay))
    }
}

actor SearchCoordinator: SearchCoordinating {
    private static let debounceDelay: TimeInterval = 0.15

    private let provider: any SearchCandidateProviding
    private let parser: SearchQueryParser
    private let merger: SearchFilterMerger
    private let ranker: SearchRanker
    private let sleeper: any SearchSleeping
    private var generation = 0

    init(
        provider: any SearchCandidateProviding,
        parser: SearchQueryParser = SearchQueryParser(),
        merger: SearchFilterMerger = SearchFilterMerger(),
        ranker: SearchRanker = SearchRanker(),
        sleeper: any SearchSleeping = DefaultSearchSleeper()
    ) {
        self.provider = provider
        self.parser = parser
        self.merger = merger
        self.ranker = ranker
        self.sleeper = sleeper
    }

    func immediateResults(
        input: String,
        loadedItems: [ClipboardHistoryItem],
        filters: SearchUIFilters
    ) -> SearchResponse {
        let parsedQuery = parser.parse(input)
        let mergedFilters = merger.merge(parsedQuery: parsedQuery, controls: filters)
        generation += 1
        return SearchResponse(
            parsedQuery: parsedQuery,
            results: ranker.rank(
                items: loadedItems.filter { matches($0, parsedQuery: parsedQuery, filters: mergedFilters) },
                terms: parsedQuery.terms
            ),
            isCurrent: true,
            errorDescription: nil
        )
    }

    func search(
        input: String,
        loadedItems: [ClipboardHistoryItem],
        filters: SearchUIFilters
    ) async -> SearchResponse {
        let parsedQuery = parser.parse(input)
        let request = candidateRequest(parsedQuery: parsedQuery, filters: filters)
        generation += 1
        let capturedGeneration = generation

        do {
            try await sleeper.sleep(for: Self.debounceDelay)
        } catch {
            return staleResponse(for: parsedQuery)
        }
        guard capturedGeneration == generation else {
            return staleResponse(for: parsedQuery)
        }

        do {
            let candidates = try await provider.candidates(for: request)
            let results = ranker.rank(items: candidates, terms: parsedQuery.terms)
            return SearchResponse(
                parsedQuery: parsedQuery,
                results: results,
                isCurrent: capturedGeneration == generation,
                errorDescription: nil
            )
        } catch {
            return SearchResponse(
                parsedQuery: parsedQuery,
                results: [],
                isCurrent: capturedGeneration == generation,
                errorDescription: error.localizedDescription
            )
        }
    }

    func cancelCurrentSearch() {
        generation += 1
    }

    private func candidateRequest(parsedQuery: ParsedSearchQuery, filters: SearchUIFilters) -> SearchCandidateRequest {
        let mergedFilters = merger.merge(parsedQuery: parsedQuery, controls: filters)
        return SearchCandidateRequest(
            parsedQuery: parsedQuery,
            storageContentType: mergedFilters.storageContentType,
            sourceFilter: mergedFilters.sourceFilter,
            timeRange: mergedFilters.timeRange,
            favoritesOnly: mergedFilters.favoritesOnly,
            limit: 500
        )
    }

    private func staleResponse(for parsedQuery: ParsedSearchQuery) -> SearchResponse {
        SearchResponse(parsedQuery: parsedQuery, results: [], isCurrent: false, errorDescription: nil)
    }

    private func matches(
        _ item: ClipboardHistoryItem,
        parsedQuery: ParsedSearchQuery,
        filters: MergedSearchFilters
    ) -> Bool {
        guard filters.storageContentType == nil || item.contentType == filters.storageContentType else {
            return false
        }
        guard parsedQuery.type == nil || item.effectiveDetectedType == parsedQuery.type else {
            return false
        }
        guard filters.favoritesOnly == false || item.isFavorite else {
            return false
        }
        guard sourceMatches(item, filter: filters.sourceFilter) else {
            return false
        }

        let capturedAt = item.lastCapturedAt ?? item.createdAt
        if let after = parsedQuery.after, capturedAt < after {
            return false
        }
        if let before = parsedQuery.before, capturedAt > before {
            return false
        }
        guard parsedQuery.before == nil, parsedQuery.after == nil,
              let startDate = filters.timeRange.startDate else {
            return true
        }
        return capturedAt >= startDate
    }

    private func sourceMatches(_ item: ClipboardHistoryItem, filter: HistoryQuery.SourceFilter) -> Bool {
        guard filter.isAll == false else { return true }
        let sourceApp = item.sourceApp?.lowercased() ?? ""
        let sourceBundleID = item.sourceBundleID?.lowercased() ?? ""
        if let appName = filter.appName?.lowercased(), appName.isEmpty == false,
           sourceApp.contains(appName) == false, sourceBundleID.contains(appName) == false {
            return false
        }
        if let bundleID = filter.bundleID?.lowercased(), bundleID.isEmpty == false,
           sourceBundleID.contains(bundleID) == false {
            return false
        }
        return true
    }
}
