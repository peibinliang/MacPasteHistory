import Foundation

protocol HistoryListFetching: AnyObject {
    func fetchHistory(query: HistoryQuery) throws -> [ClipboardHistoryItem]
    func fetchSourceOptions() throws -> [HistorySourceOption]
}

extension ClipboardHistoryRepository: HistoryListFetching {}

struct HistoryListSnapshot {
    let items: [ClipboardHistoryItem]
    let sourceOptions: [HistorySourceOption]
}

@MainActor
protocol HistoryListCoordinating: AnyObject {
    var isShowingRankedResults: Bool { get }
    var currentOffset: Int { get }
    var canLoadMore: Bool { get }

    func load(query: HistoryQuery) throws -> HistoryListSnapshot
    func loadMore(query: HistoryQuery) throws -> [ClipboardHistoryItem]
    func showRankedResults(_ results: [ClipboardHistoryItem]) -> [ClipboardHistoryItem]
    func revealMoreRankedResults(currentItemID: Int64?, displayedLastItemID: Int64?) -> [ClipboardHistoryItem]?
}

@MainActor
final class HistoryListCoordinator: HistoryListCoordinating {
    private let provider: any HistoryListFetching
    private let pageSize: Int
    private(set) var currentOffset = 0
    private(set) var canLoadMore = true
    private(set) var isShowingRankedResults = false
    private var rankedCandidates: [ClipboardHistoryItem] = []
    private var visibleCandidateCount = 0

    init(provider: any HistoryListFetching, pageSize: Int) {
        self.provider = provider
        self.pageSize = pageSize
    }

    func load(query: HistoryQuery) throws -> HistoryListSnapshot {
        isShowingRankedResults = false
        rankedCandidates = []
        visibleCandidateCount = 0
        currentOffset = 0
        let items = try provider.fetchHistory(query: query)
        let sourceOptions = try provider.fetchSourceOptions()
        currentOffset = items.count
        canLoadMore = items.count == pageSize
        return HistoryListSnapshot(items: items, sourceOptions: sourceOptions)
    }

    func loadMore(query: HistoryQuery) throws -> [ClipboardHistoryItem] {
        let items = try provider.fetchHistory(query: query)
        currentOffset += items.count
        canLoadMore = items.count == pageSize
        return items
    }

    func showRankedResults(_ results: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        isShowingRankedResults = true
        rankedCandidates = results
        visibleCandidateCount = min(pageSize, results.count)
        return Array(results.prefix(visibleCandidateCount))
    }

    func revealMoreRankedResults(
        currentItemID: Int64?,
        displayedLastItemID: Int64?
    ) -> [ClipboardHistoryItem]? {
        guard currentItemID == displayedLastItemID,
              visibleCandidateCount < rankedCandidates.count else {
            return nil
        }
        visibleCandidateCount = min(visibleCandidateCount + pageSize, rankedCandidates.count)
        return Array(rankedCandidates.prefix(visibleCandidateCount))
    }
}

@MainActor
protocol SearchTaskLifecycleManaging: AnyObject {
    func beginRequest() -> Int
    func retain(_ task: Task<Void, Never>, for requestID: Int)
    func isCurrent(_ requestID: Int) -> Bool
    func finish(_ requestID: Int)
    func invalidate()
}

@MainActor
final class SearchTaskLifecycle: SearchTaskLifecycleManaging {
    private var task: Task<Void, Never>?
    private var requestID = 0

    func beginRequest() -> Int {
        task?.cancel()
        requestID += 1
        return requestID
    }

    func retain(_ task: Task<Void, Never>, for requestID: Int) {
        guard self.requestID == requestID else {
            task.cancel()
            return
        }
        self.task = task
    }

    func isCurrent(_ requestID: Int) -> Bool {
        self.requestID == requestID && Task.isCancelled == false
    }

    func finish(_ requestID: Int) {
        if self.requestID == requestID {
            task = nil
        }
    }

    func invalidate() {
        task?.cancel()
        task = nil
        requestID += 1
    }

    deinit {
        task?.cancel()
    }
}

@MainActor
protocol HistorySelectionManaging: AnyObject {
    var selectedItemID: Int64? { get }
    func select(_ itemID: Int64?)
}

@MainActor
final class HistorySelectionState: HistorySelectionManaging {
    private(set) var selectedItemID: Int64?

    func select(_ itemID: Int64?) {
        selectedItemID = itemID
    }
}
