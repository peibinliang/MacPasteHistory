import Foundation
import Combine

@MainActor
final class ClipboardHistoryViewModel: ObservableObject, ClipboardContentWriting, PasteUsageRecording {
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
    @Published private(set) var selectedItemID: Int64?

    private let repository: ClipboardHistoryRepository
    private let writer: ClipboardWriter
    private let imageStorageService: ImageStorageService?
    private let pageSize: Int
    private let searchCoordinator: (any SearchCoordinating)?
    private var currentOffset = 0
    private var canLoadMore = true
    private var rankedCandidates: [ClipboardHistoryItem] = []
    private var visibleCandidateCount = 0
    private var isShowingRankedResults = false
    private var searchTask: Task<Void, Never>?
    private var searchRequestID = 0
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
            isShowingRankedResults = false
            rankedCandidates = []
            visibleCandidateCount = 0
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
        searchTask?.cancel()
        searchRequestID += 1
        let requestID = searchRequestID
        searchText = text
        let parsed = SearchQueryParser().parse(text)
        parsedSearchQuery = parsed
        searchTokens = parsed.tokens
        highlightedTerms = parsed.terms
        searchSuggestions = SearchSuggestionProvider(sourceOptions: sourceOptions).suggestions(for: text)
        guard let searchCoordinator else { loadHistory(); return }
        let filters = SearchUIFilters(selectedSourceOption: selectedSourceOption, selectedContentType: selectedContentType, isFavoritesOnly: isFavoritesOnly, selectedTimeRange: selectedTimeRange)
        searchTask = Task { [weak self] in
            guard let self else { return }
            guard isCurrentSearchRequest(requestID) else { return }
            await searchCoordinator.cancelCurrentSearch()
            guard isCurrentSearchRequest(requestID) else { return }
            isSearchLoading = true
            defer {
                if searchRequestID == requestID {
                    isSearchLoading = false
                }
            }
            let immediate = await searchCoordinator.immediateResults(input: text, loadedItems: items, filters: filters)
            guard isCurrentSearchRequest(requestID), immediate.isCurrent else { return }
            showRankedResults(immediate.results.map(\.item))
            let full = await searchCoordinator.search(input: text, loadedItems: items, filters: filters)
            guard isCurrentSearchRequest(requestID), full.isCurrent else { return }
            if let errorDescription = full.errorDescription {
                errorMessage = errorDescription
            } else {
                showRankedResults(full.results.map(\.item))
                errorMessage = nil
            }
        }
    }

    private func isCurrentSearchRequest(_ requestID: Int) -> Bool {
        searchRequestID == requestID && Task.isCancelled == false
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
        if isShowingRankedResults {
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

    func setUserOverrideType(_ type: DetectedContentType?, for item: ClipboardHistoryItem) {
        do {
            try repository.updateUserOverrideType(id: item.id, type: type)
            refreshSearch()
        } catch {
            errorMessage = L10n.string("Failed to update clipboard content type.")
        }
    }

    func sourceRecordExists(for item: ClipboardHistoryItem) -> Bool {
        guard let sourceID = item.derivedFromHistoryID else { return true }
        return (try? repository.historyItem(id: sourceID)) != nil
    }

    func makeOCRViewModel() -> OCRViewModel {
        OCRViewModel(repository: repository, didSave: { [weak self] in self?.refreshSearch() })
    }

    func applyPasteOutcome(_ outcome: PasteOutcome) {
        switch outcome {
        case .pasted, .clipboardOnly, .permissionRequired, .cancelled:
            errorMessage = nil
        case let .failed(failure):
            switch failure {
            case .clipboardWrite:
                errorMessage = L10n.string("Failed to restore text to clipboard.")
            case .dispatchPreparation:
                errorMessage = L10n.string("Paste was not sent. Press Command-V to paste manually.")
            case .usageAccounting:
                errorMessage = L10n.string("Failed to record clipboard usage.")
            }
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

    func pasteRequest(for item: ClipboardHistoryItem) -> PasteRequest? {
        switch item.contentType {
        case .text:
            return PasteRequest(payload: .text(item.textContent), historyID: item.id)
        case .image:
            guard let filePath = item.filePath,
                  let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
                errorMessage = L10n.string("Failed to restore image to clipboard.")
                return nil
            }
            return PasteRequest(payload: .image(data), historyID: item.id)
        }
    }

    func actionOutputPasteRequest(_ output: String, sourceItem: ClipboardHistoryItem) -> PasteRequest {
        PasteRequest(payload: .text(output), historyID: sourceItem.id)
    }

    func writeText(_ text: String) -> Bool {
        guard writer.writeText(text) else {
            errorMessage = L10n.string("Failed to restore text to clipboard.")
            return false
        }
        errorMessage = nil
        return true
    }

    func writeImage(_ data: Data) -> Bool {
        guard writer.writeImage(data) else {
            errorMessage = L10n.string("Failed to restore image to clipboard.")
            return false
        }
        errorMessage = nil
        return true
    }

    func recordReuseCopy(historyID: Int64, at date: Date) throws {
        do {
            try repository.recordReuseCopy(historyID: historyID, at: date)
            errorMessage = nil
        } catch {
            errorMessage = L10n.string("Failed to record clipboard usage.")
            throw error
        }
    }

    func recordPaste(historyID: Int64, at date: Date) throws {
        do {
            try repository.recordPaste(historyID: historyID, at: date)
            errorMessage = nil
        } catch {
            errorMessage = L10n.string("Failed to record clipboard usage.")
            throw error
        }
    }

    @discardableResult
    func copyActionOutput(_ output: String, sourceItem: ClipboardHistoryItem) -> Bool {
        guard writer.writeText(output) else {
            errorMessage = L10n.string("Failed to restore text to clipboard.")
            return false
        }
        do {
            try repository.recordReuseCopy(historyID: sourceItem.id, at: Date())
            errorMessage = nil
            return true
        } catch {
            errorMessage = L10n.string("Failed to record clipboard usage.")
            return false
        }
    }

    @discardableResult
    func pasteActionOutput(_ output: String, sourceItem: ClipboardHistoryItem, pasteCommandService: PasteCommandService) -> Bool {
        guard writer.writeText(output) else {
            errorMessage = L10n.string("Failed to restore text to clipboard.")
            return false
        }
        do {
            if pasteCommandService.sendPasteCommand() {
                try repository.recordPaste(historyID: sourceItem.id, at: Date())
                errorMessage = nil
                return true
            }
            try repository.recordReuseCopy(historyID: sourceItem.id, at: Date())
            errorMessage = L10n.string("Paste was not sent. Press Command-V to paste manually.")
            return false
        } catch {
            errorMessage = L10n.string("Failed to record clipboard usage.")
            return false
        }
    }

    @discardableResult
    func recordClipboardOnlyUsage(for item: ClipboardHistoryItem) -> Bool {
        do {
            try repository.recordReuseCopy(historyID: item.id, at: Date())
            errorMessage = nil
            return true
        } catch {
            errorMessage = L10n.string("Failed to record clipboard usage.")
            return false
        }
    }

    @discardableResult
    func sendPasteForRestoredItem(_ item: ClipboardHistoryItem, pasteCommandService: PasteCommandService) -> Bool {
        do {
            if pasteCommandService.sendPasteCommand() {
                try repository.recordPaste(historyID: item.id, at: Date())
                errorMessage = nil
                return true
            }
            try repository.recordReuseCopy(historyID: item.id, at: Date())
            errorMessage = L10n.string("Paste was not sent. Press Command-V to paste manually.")
            return false
        } catch {
            errorMessage = L10n.string("Failed to record clipboard usage.")
            return false
        }
    }

    @discardableResult
    func saveDerivedActionOutput(from session: ActionSession) -> ClipboardHistoryItem? {
        guard let currentStep = session.currentStep else { return nil }
        do {
            let source = session.sourceItem
            let item = try repository.saveDerivedText(DerivedClipboardRecordRequest(
                text: session.currentOutput,
                sourceHistoryID: source.id,
                actionID: currentStep.actionID.rawValue,
                actionSummary: session.currentActionSummary,
                sourcePreview: DerivedSourcePreviewBuilder.build(for: source),
                sourceHash: source.contentHash,
                detection: ContentClassifier().classifyFast(session.currentOutput)
            ))
            refreshSearch()
            selectedItemID = item.id
            errorMessage = item.id == source.id ? L10n.string("Existing clipboard record was reused.") : nil
            return item
        } catch {
            errorMessage = L10n.string("Failed to save derived clipboard content.")
            return nil
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
        isShowingRankedResults = true
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
