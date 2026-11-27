import Foundation
import Combine

@MainActor
final class ClipboardHistoryViewModel: ObservableObject, ClipboardContentWriting, PasteUsageRecording {
    @Published private(set) var items: [ClipboardHistoryItem] = []
    @Published private(set) var timelineSections: [HistoryTimelineSection] = []
    @Published private(set) var recentSources: [HistoryRecentSource] = []
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
    private let historySnapshotLoader: (any HistoryListSnapshotLoading)?
    private let timelineOrganizer = HistoryTimelineOrganizer()
    private var historyDidChangeCancellable: AnyCancellable?
    private var historyLoadTask: Task<Void, Never>?
    private var historyLoadGeneration = 0
    private var isPanelVisible = true
    private var hasPendingHistoryRefresh = false

    init(
        repository: ClipboardHistoryRepository,
        writer: ClipboardWriter,
        imageStorageService: ImageStorageService? = nil,
        pageSize: Int = 50,
        searchCoordinator: (any SearchCoordinating)? = nil,
        listCoordinator: (any HistoryListCoordinating)? = nil,
        searchLifecycle: (any SearchTaskLifecycleManaging)? = nil,
        selectionState: (any HistorySelectionManaging)? = nil,
        historySnapshotLoader: (any HistoryListSnapshotLoading)? = nil
    ) {
        self.repository = repository
        self.writer = writer
        self.imageStorageService = imageStorageService
        self.pageSize = pageSize
        self.searchCoordinator = searchCoordinator
        self.listCoordinator = listCoordinator ?? HistoryListCoordinator(provider: repository, pageSize: pageSize)
        self.searchLifecycle = searchLifecycle ?? SearchTaskLifecycle()
        self.selectionState = selectionState ?? HistorySelectionState()
        self.historySnapshotLoader = historySnapshotLoader
        historyDidChangeCancellable = NotificationCenter.default.publisher(for: .clipboardHistoryDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleClipboardHistoryDidChange()
            }
    }

    deinit {
        historyLoadTask?.cancel()
    }

    func setPanelVisible(_ visible: Bool) {
        if visible {
            let wasHidden = isPanelVisible == false
            isPanelVisible = true
            if hasPendingHistoryRefresh || items.isEmpty {
                hasPendingHistoryRefresh = false
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    loadHistoryAsync()
                } else {
                    refreshSearch()
                }
            } else if wasHidden {
                timelineSections = timelineOrganizer.sections(for: items)
            }
        } else {
            isPanelVisible = false
            historyLoadTask?.cancel()
            historyLoadTask = nil
            searchLifecycle.invalidate()
            isSearchLoading = false
            if items.count > pageSize {
                let retained = Array(items.prefix(pageSize))
                listCoordinator.trimToFirstPage(retainedCount: retained.count, hasMore: true)
                updateDisplayedItems(retained)
            }
        }
    }

    func loadHistory() {
        historyLoadTask?.cancel()
        historyLoadTask = nil
        historyLoadGeneration += 1
        searchLifecycle.invalidate()
        isSearchLoading = false
        hasPendingHistoryRefresh = false
        do {
            let snapshot = try listCoordinator.load(query: currentQuery(offset: 0))
            applyHistorySnapshot(snapshot, adoptInCoordinator: false)
        } catch {
            errorMessage = L10n.string("Failed to load clipboard history.")
        }
    }

    func loadHistoryAsync() {
        guard let historySnapshotLoader else {
            loadHistory()
            return
        }
        historyLoadTask?.cancel()
        historyLoadGeneration += 1
        let generation = historyLoadGeneration
        let query = currentQuery(offset: 0)
        searchLifecycle.invalidate()
        isSearchLoading = false
        hasPendingHistoryRefresh = false
        historyLoadTask = Task { [weak self] in
            do {
                let snapshot = try await historySnapshotLoader.load(query: query)
                guard Task.isCancelled == false else { return }
                guard let self, self.historyLoadGeneration == generation else { return }
                self.applyHistorySnapshot(snapshot, adoptInCoordinator: true)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.historyLoadGeneration == generation else { return }
                self.errorMessage = L10n.string("Failed to load clipboard history.")
            }
        }
    }

    private func handleClipboardHistoryDidChange() {
        guard isPanelVisible else {
            hasPendingHistoryRefresh = true
            return
        }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            loadHistoryAsync()
        } else {
            refreshSearch()
        }
    }

    private func applyHistorySnapshot(_ snapshot: HistoryListSnapshot, adoptInCoordinator: Bool) {
        if adoptInCoordinator {
            listCoordinator.adoptLoadedSnapshot(itemCount: snapshot.items.count)
        }
        updateDisplayedItems(snapshot.items)
        sourceOptions = snapshot.sourceOptions
        if let selectedSourceOption, sourceOptions.contains(selectedSourceOption) == false {
            self.selectedSourceOption = nil
        }
        errorMessage = nil
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
        if updatedText == parsedSearchQuery.rawInput,
           token.range.lowerBound >= updatedText.startIndex,
           token.range.upperBound <= updatedText.endIndex,
           token.range.lowerBound.samePosition(in: updatedText.unicodeScalars) != nil,
           token.range.upperBound.samePosition(in: updatedText.unicodeScalars) != nil {
            updatedText.removeSubrange(token.range)
        } else {
            let reparsed = SearchQueryParser().parse(updatedText)
            if let matchedToken = reparsed.tokens.first(where: { $0.kind == token.kind }) {
                updatedText.removeSubrange(matchedToken.range)
            }
        }
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
                updateDisplayedItems(visibleItems)
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
            updateDisplayedItems(items + loadedItems)
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
        updateDisplayedItems(listCoordinator.showRankedResults(results))
    }

    private func updateDisplayedItems(_ newItems: [ClipboardHistoryItem]) {
        items = newItems
        timelineSections = timelineOrganizer.sections(for: newItems)
        recentSources = timelineOrganizer.recentSources(from: newItems, limit: 6)
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
