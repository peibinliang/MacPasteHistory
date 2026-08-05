import Foundation
import Combine

@MainActor
final class ClipboardHistoryViewModel: ObservableObject {
    @Published private(set) var items: [ClipboardHistoryItem] = []
    @Published var searchText = ""
    @Published private(set) var parsedSearchQuery = SearchQueryParser().parse("")
    @Published private(set) var searchTokens: [SearchToken] = []
    @Published private(set) var searchSuggestions: [SearchSuggestion] = []
    @Published private(set) var isSearchLoading = false
    @Published private(set) var highlightedTerms: [String] = []
    @Published var isFavoritesOnly = false
    @Published var selectedContentType: ClipboardContentType?
    @Published var selectedTimeRange: HistoryQuery.TimeRange = .all
    @Published var selectedSourceOption: HistorySourceOption?
    @Published private(set) var sourceOptions: [HistorySourceOption] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoadingMore = false

    private let repository: ClipboardHistoryRepository
    private let writer: ClipboardWriter
    private let imageStorageService: ImageStorageService?
    private let pageSize: Int
    private let searchCoordinator: (any SearchCoordinating)?
    private var currentOffset = 0
    private var canLoadMore = true
    private var rankedCandidates: [ClipboardHistoryItem] = []
    private var visibleCandidateCount = 0
    private var historyDidChangeCancellable: AnyCancellable?

    init(
        repository: ClipboardHistoryRepository,
        writer: ClipboardWriter,
        imageStorageService: ImageStorageService? = nil,
        pageSize: Int = 50,
        searchCoordinator: (any SearchCoordinating)? = nil
    ) {
        self.repository = repository
        self.writer = writer
        self.imageStorageService = imageStorageService
        self.pageSize = pageSize
        self.searchCoordinator = searchCoordinator
        historyDidChangeCancellable = NotificationCenter.default.publisher(for: .clipboardHistoryDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadHistory()
            }
    }

    func loadHistory() {
        do {
            currentOffset = 0
            let loadedItems = try repository.fetchHistory(query: currentQuery(offset: currentOffset))
            items = loadedItems
            sourceOptions = try repository.fetchSourceOptions()
            if let selectedSourceOption, sourceOptions.contains(selectedSourceOption) == false {
                self.selectedSourceOption = nil
            }
            currentOffset = loadedItems.count
            canLoadMore = loadedItems.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = L10n.string("Failed to load clipboard history.")
        }
    }

    func search() {
        updateSearchText(searchText)
    }

    func updateSearchText(_ text: String) {
        searchText = text
        let parsed = SearchQueryParser().parse(text)
        parsedSearchQuery = parsed
        searchTokens = parsed.tokens
        highlightedTerms = parsed.terms
        searchSuggestions = SearchSuggestionProvider(sourceOptions: sourceOptions).suggestions(for: text)
        guard let searchCoordinator else { loadHistory(); return }
        let filters = SearchUIFilters(selectedSourceOption: selectedSourceOption, selectedContentType: selectedContentType, isFavoritesOnly: isFavoritesOnly, selectedTimeRange: selectedTimeRange)
        Task { [weak self] in
            guard let self else { return }
            isSearchLoading = true
            let immediate = await searchCoordinator.immediateResults(input: text, loadedItems: items, filters: filters)
            guard immediate.isCurrent else {
                isSearchLoading = false
                return
            }
            showRankedResults(immediate.results.map(\.item))
            let full = await searchCoordinator.search(input: text, loadedItems: items, filters: filters)
            guard full.isCurrent else {
                isSearchLoading = false
                return
            }
            if let errorDescription = full.errorDescription {
                errorMessage = errorDescription
            } else {
                showRankedResults(full.results.map(\.item))
                errorMessage = nil
            }
            isSearchLoading = false
        }
    }

    func acceptSuggestion(_ suggestion: SearchSuggestion) {
        let accepted = suggestion.applying(to: searchText)
        updateSearchText(accepted.text)
    }

    func removeSearchToken(_ token: SearchToken) {
        var updatedText = searchText
        updatedText.removeSubrange(token.range)
        updatedText = updatedText
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        updateSearchText(updatedText)
    }

    func refreshSearch() {
        updateSearchText(searchText)
    }

    func dismissSearchSuggestions() {
        searchSuggestions = []
    }

    func loadMoreIfNeeded(currentItem: ClipboardHistoryItem?) {
        if searchCoordinator != nil {
            guard currentItem?.id == items.last?.id,
                  visibleCandidateCount < rankedCandidates.count else {
                return
            }
            visibleCandidateCount = min(visibleCandidateCount + pageSize, rankedCandidates.count)
            items = Array(rankedCandidates.prefix(visibleCandidateCount))
            return
        }
        guard canLoadMore, isLoadingMore == false else {
            return
        }
        guard currentItem?.id == items.last?.id else {
            return
        }

        isLoadingMore = true
        defer {
            isLoadingMore = false
        }

        do {
            let loadedItems = try repository.fetchHistory(query: currentQuery(offset: currentOffset))
            items.append(contentsOf: loadedItems)
            currentOffset += loadedItems.count
            canLoadMore = loadedItems.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = L10n.string("Failed to load more clipboard history.")
        }
    }

    @discardableResult
    func restore(_ item: ClipboardHistoryItem) -> Bool {
        if item.contentType == .image {
            return restoreImage(item)
        }

        guard writer.writeText(item.textContent) else {
            errorMessage = L10n.string("Failed to restore text to clipboard.")
            return false
        }
        errorMessage = nil
        return true
    }

    func delete(_ item: ClipboardHistoryItem) {
        do {
            if item.contentType == .image {
                imageStorageService?.deleteImageFiles(for: item)
            }
            try repository.deleteItem(id: item.id)
            loadHistory()
        } catch {
            errorMessage = L10n.string("Failed to delete clipboard history item.")
        }
    }

    func toggleFavorite(_ item: ClipboardHistoryItem) {
        do {
            try repository.setFavorite(!item.isFavorite, id: item.id)
            loadHistory()
        } catch {
            errorMessage = L10n.string("Failed to update favorite state.")
        }
    }

    func clearTextHistory() {
        do {
            try repository.clearTextHistory()
            loadHistory()
        } catch {
            errorMessage = L10n.string("Failed to clear clipboard history.")
        }
    }

    private func currentQuery(offset: Int) -> HistoryQuery {
        HistoryQuery(
            keyword: searchText,
            favoritesOnly: isFavoritesOnly,
            contentType: selectedContentType,
            timeRange: selectedTimeRange,
            sourceFilter: selectedSourceOption?.filter ?? .all,
            limit: pageSize,
            offset: offset
        )
    }

    private func showRankedResults(_ results: [ClipboardHistoryItem]) {
        rankedCandidates = results
        visibleCandidateCount = min(pageSize, rankedCandidates.count)
        items = Array(rankedCandidates.prefix(visibleCandidateCount))
    }

    private func restoreImage(_ item: ClipboardHistoryItem) -> Bool {
        guard let filePath = item.filePath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              writer.writeImage(data) else {
            errorMessage = L10n.string("Failed to restore image to clipboard.")
            return false
        }
        errorMessage = nil
        return true
    }
}
