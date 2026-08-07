import XCTest

@testable import MacPasteHistory

@MainActor
final class SearchViewModelTests: XCTestCase {
    func testUpdateSearchText_publishesImmediateResultsAndIgnoresStaleFullResponse() async {
        let coordinator = FakeSearchCoordinator()
        let viewModel = ClipboardHistoryViewModel(
            repository: try! testRepository(),
            writer: ClipboardWriter(restorationState: ClipboardRestorationState()),
            searchCoordinator: coordinator
        )
        let immediate = item(id: 1, text: "json immediate")
        let stale = item(id: 2, text: "old")
        await coordinator.setImmediate([immediate])
        await coordinator.setFull([stale], isCurrent: false)

        viewModel.updateSearchText("json")
        for _ in 0..<10 {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.items.map { $0.id }, [immediate.id])
    }

    func testLoadMore_revealsNextPageFromRankedCandidatesWithoutAnotherSearch() async throws {
        let coordinator = FakeSearchCoordinator()
        let viewModel = ClipboardHistoryViewModel(
            repository: try testRepository(),
            writer: ClipboardWriter(restorationState: ClipboardRestorationState()),
            pageSize: 2,
            searchCoordinator: coordinator
        )
        let results = (1...3).map { item(id: Int64($0), text: "item \($0)") }
        await coordinator.setImmediate(results)
        await coordinator.setFull(results, isCurrent: true)

        viewModel.updateSearchText("item")
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(viewModel.items.map(\.id), [1, 2])

        viewModel.loadMoreIfNeeded(currentItem: viewModel.items.last)
        XCTAssertEqual(viewModel.items.map(\.id), [1, 2, 3])
    }

    func testSearchError_preservesImmediateItemsAndExposesError() async throws {
        let coordinator = FakeSearchCoordinator()
        let viewModel = ClipboardHistoryViewModel(
            repository: try testRepository(),
            writer: ClipboardWriter(restorationState: ClipboardRestorationState()),
            searchCoordinator: coordinator
        )
        let immediate = item(id: 1, text: "immediate")
        await coordinator.setImmediate([immediate])
        await coordinator.setError("Search unavailable")

        viewModel.updateSearchText("immediate")
        for _ in 0..<10 { await Task.yield() }

        XCTAssertEqual(viewModel.items.map(\.id), [immediate.id])
        XCTAssertEqual(viewModel.errorMessage, "Search unavailable")
    }

    private func testRepository() throws -> ClipboardHistoryRepository {
        let database = try DatabaseConnection(databaseURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try MigrationManager(database: database).migrate()
        return ClipboardHistoryRepository(database: database)
    }

    private func item(id: Int64, text: String) -> ClipboardHistoryItem {
        ClipboardHistoryItem(id: id, contentType: .text, textContent: text, filePath: nil, thumbnailPath: nil, sourceApp: nil, sourceBundleID: nil, contentHash: "h\(id)", textLength: text.count, fileSize: nil, imageWidth: nil, imageHeight: nil, imageFormat: nil, isFavorite: false, isSensitive: false, createdAt: Date(), updatedAt: Date(), searchableText: text)
    }
}

private actor FakeSearchCoordinator: SearchCoordinating {
    private var immediateItems: [ClipboardHistoryItem] = []
    private var fullItems: [ClipboardHistoryItem] = []
    private var isCurrent = true
    private var errorDescription: String?

    func setImmediate(_ items: [ClipboardHistoryItem]) { immediateItems = items }
    func setFull(_ items: [ClipboardHistoryItem], isCurrent: Bool) { fullItems = items; self.isCurrent = isCurrent }
    func setError(_ errorDescription: String?) { self.errorDescription = errorDescription }
    func immediateResults(input: String, loadedItems: [ClipboardHistoryItem], filters: SearchUIFilters) async -> SearchResponse { response(items: immediateItems, isCurrent: true, input: input) }
    func search(input: String, loadedItems: [ClipboardHistoryItem], filters: SearchUIFilters) async -> SearchResponse { response(items: fullItems, isCurrent: isCurrent, input: input) }
    func cancelCurrentSearch() async {}

    private func response(items: [ClipboardHistoryItem], isCurrent: Bool, input: String) -> SearchResponse {
        SearchResponse(parsedQuery: SearchQueryParser().parse(input), results: items.map { RankedSearchResult(item: $0, score: 1, matchedTerms: []) }, isCurrent: isCurrent, errorDescription: errorDescription)
    }
}
