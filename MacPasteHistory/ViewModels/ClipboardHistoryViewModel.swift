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
    private let listCoordinator: any HistoryListCoordinating
    private let searchLifecycle: any SearchTaskLifecycleManaging
    private let selectionState: any HistorySelectionManaging
    private var historyDidChangeCancellable: AnyCancellable?

    init(
        repository: ClipboardHistoryRepository,
        writer: ClipboardWriter,
        imageStorageService: ImageStorageService? = nil,
        pageSize: Int = 50,
        searchCoordinator: (any SearchCoordinating)? = nil,
        listCoordinator: (any HistoryListCoordinating)? = nil,
        searchLifecycle: (any SearchTaskLifecycleManaging)? = nil,
        selectionState: (any HistorySelectionManaging)? = nil
    ) {
        self.repository = repository
        self.writer = writer
        self.imageStorageService = imageStorageService
        self.pageSize = pageSize
        self.searchCoordinator = searchCoordinator
        self.listCoordinator = listCoordinator ?? HistoryListCoordinator(provider: repository, pageSize: pageSize)
        self.searchLifecycle = searchLifecycle ?? SearchTaskLifecycle()
        self.selectionState = selectionState ?? HistorySelectionState()
        historyDidChangeCancellable = NotificationCenter.default.publisher(for: .clipboardHistoryDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadHistory()
            }
    }

    func loadHistory() {
        searchLifecycle.invalidate()
        isSearchLoading = false
        do {
            let snapshot = try listCoordinator.load(query: currentQuery(offset: 0))
            items = snapshot.items
            sourceOptions = snapshot.sourceOptions
            if let selectedSourceOption, sourceOptions.contains(selectedSourceOption) == false {
                self.selectedSourceOption = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = L10n.string("Failed to load clipboard history.")
        }
    }

    func search() {
        updateSearchText(searchText)
    }

    func updateSearchText(_ text: String) {
        let requestID = searchLifecycle.beginRequest()
        searchText = text
        let parsed = SearchQueryParser().parse(text)
        parsedSearchQuery = parsed
        searchTokens = parsed.tokens
        highlightedTerms = parsed.terms
        searchSuggestions = SearchSuggestionProvider(sourceOptions: sourceOptions).suggestions(for: text)
        guard let searchCoordinator else { loadHistory(); return }
        let filters = SearchUIFilters(selectedSourceOption: selectedSourceOption, selectedContentType: selectedContentType, isFavoritesOnly: isFavoritesOnly, selectedTimeRange: selectedTimeRange)
        let loadedItems = items
        let task = Task { [weak self] in
            guard self?.isCurrentSearchRequest(requestID) == true else { return }
            await searchCoordinator.cancelCurrentSearch()
            guard self?.isCurrentSearchRequest(requestID) == true else { return }
            self?.isSearchLoading = true
            defer {
                self?.finishSearchRequest(requestID)
            }
            let immediate = await searchCoordinator.immediateResults(
                input: text,
                loadedItems: loadedItems,
                filters: filters
            )
            guard self?.isCurrentSearchRequest(requestID) == true, immediate.isCurrent else { return }
            self?.showRankedResults(immediate.results.map(\.item))
            let full = await searchCoordinator.search(
                input: text,
                loadedItems: loadedItems,
                filters: filters
            )
            guard self?.isCurrentSearchRequest(requestID) == true, full.isCurrent else { return }
            if let errorDescription = full.errorDescription {
                self?.errorMessage = errorDescription
            } else {
                self?.showRankedResults(full.results.map(\.item))
                self?.errorMessage = nil
            }
        }
        searchLifecycle.retain(task, for: requestID)
    }

    private func isCurrentSearchRequest(_ requestID: Int) -> Bool {
        searchLifecycle.isCurrent(requestID)
    }

    private func finishSearchRequest(_ requestID: Int) {
        if searchLifecycle.isCurrent(requestID) {
            isSearchLoading = false
        }
        searchLifecycle.finish(requestID)
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
        if listCoordinator.isShowingRankedResults {
            if let visibleItems = listCoordinator.revealMoreRankedResults(
                currentItemID: currentItem?.id,
                displayedLastItemID: items.last?.id
            ) {
                items = visibleItems
            }
            return
        }
        guard listCoordinator.canLoadMore, isLoadingMore == false else {
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
            let loadedItems = try listCoordinator.loadMore(
                query: currentQuery(offset: listCoordinator.currentOffset)
            )
            items.append(contentsOf: loadedItems)
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
                if errorMessage == nil {
                    errorMessage = L10n.string("Failed to restore text to clipboard.")
                }
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
            selectionState.select(item.id)
            selectedItemID = selectionState.selectedItemID
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
        items = listCoordinator.showRankedResults(results)
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
