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

    func testUpdateSearchText_whenSuperseded_shouldCancelOldTaskAndKeepLatestResult() async throws {
        let coordinator = ControlledViewModelSearchCoordinator()
        let viewModel = ClipboardHistoryViewModel(
            repository: try testRepository(),
            writer: ClipboardWriter(restorationState: ClipboardRestorationState()),
            searchCoordinator: coordinator
        )
        let firstImmediate = item(id: 10, text: "first immediate")
        let firstFull = item(id: 11, text: "first full")
        let secondImmediate = item(id: 20, text: "second immediate")
        let secondFull = item(id: 21, text: "second full")
        await coordinator.configure(input: "first", immediate: [firstImmediate], full: [firstFull])
        await coordinator.configure(input: "second", immediate: [secondImmediate], full: [secondFull])

        viewModel.updateSearchText("first")
        await coordinator.waitUntilStarted("first")
        XCTAssertEqual(viewModel.items.map(\.id), [firstImmediate.id])
        XCTAssertTrue(viewModel.isSearchLoading)

        viewModel.updateSearchText("second")
        await coordinator.waitUntilStarted("second")
        let firstWasCancelled = await coordinator.waitUntilCancelled("first")
        XCTAssertTrue(firstWasCancelled)
        XCTAssertEqual(viewModel.items.map(\.id), [secondImmediate.id])

        await coordinator.release("second")
        await waitUntil { viewModel.isSearchLoading == false }
        XCTAssertEqual(viewModel.items.map(\.id), [secondFull.id])

        await coordinator.release("first")
        await Task.yield()
        XCTAssertEqual(viewModel.items.map(\.id), [secondFull.id])
    }

    func testUpdateSearchText_whenNewestSearchFails_shouldPreserveItsImmediateResultAndError() async throws {
        let coordinator = ControlledViewModelSearchCoordinator()
        let viewModel = ClipboardHistoryViewModel(
            repository: try testRepository(),
            writer: ClipboardWriter(restorationState: ClipboardRestorationState()),
            searchCoordinator: coordinator
        )
        let oldFull = item(id: 31, text: "old full")
        let newestImmediate = item(id: 40, text: "newest immediate")
        await coordinator.configure(input: "old", immediate: [], full: [oldFull])
        await coordinator.configure(
            input: "newest",
            immediate: [newestImmediate],
            full: [],
            errorDescription: "Newest search unavailable"
        )

        viewModel.updateSearchText("old")
        await coordinator.waitUntilStarted("old")
        viewModel.updateSearchText("newest")
        await coordinator.waitUntilStarted("newest")
        await coordinator.release("newest")
        await waitUntil { viewModel.isSearchLoading == false }

        XCTAssertEqual(viewModel.items.map(\.id), [newestImmediate.id])
        XCTAssertEqual(viewModel.errorMessage, "Newest search unavailable")

        await coordinator.release("old")
        await Task.yield()
        XCTAssertEqual(viewModel.items.map(\.id), [newestImmediate.id])
        XCTAssertEqual(viewModel.errorMessage, "Newest search unavailable")
    }

    func testUpdateSearchText_whenInputChangesRapidly_shouldCancelEverySupersededTask() async throws {
        let coordinator = ControlledViewModelSearchCoordinator()
        let viewModel = ClipboardHistoryViewModel(
            repository: try testRepository(),
            writer: ClipboardWriter(restorationState: ClipboardRestorationState()),
            searchCoordinator: coordinator
        )
        for input in ["j", "js", "json"] {
            await coordinator.configure(input: input, immediate: [], full: [])
            viewModel.updateSearchText(input)
            await coordinator.waitUntilStarted(input)
        }

        let firstWasCancelled = await coordinator.waitUntilCancelled("j")
        let secondWasCancelled = await coordinator.waitUntilCancelled("js")
        let latestWasCancelled = await coordinator.wasCancelled("json")
        XCTAssertTrue(firstWasCancelled)
        XCTAssertTrue(secondWasCancelled)
        XCTAssertFalse(latestWasCancelled)

        await coordinator.releaseAll()
        await waitUntil { viewModel.isSearchLoading == false }
    }

    func testLoadHistory_whileSearchIsRunning_shouldCancelSearchAndKeepRepositoryResults() async throws {
        let coordinator = ControlledViewModelSearchCoordinator()
        let repository = try testRepository()
        let repositoryItem = try repository.saveText("query repository", sourceApp: nil, sourceBundleID: nil)
        let viewModel = ClipboardHistoryViewModel(
            repository: repository,
            writer: ClipboardWriter(restorationState: ClipboardRestorationState()),
            searchCoordinator: coordinator
        )
        await coordinator.configure(
            input: "query",
            immediate: [item(id: 50, text: "query immediate")],
            full: [item(id: 51, text: "query stale full")]
        )

        viewModel.updateSearchText("query")
        await coordinator.waitUntilStarted("query")
        await waitUntil { viewModel.isSearchLoading }
        viewModel.loadHistory()

        let wasCancelled = await coordinator.waitUntilCancelled("query")
        XCTAssertTrue(wasCancelled)
        XCTAssertFalse(viewModel.isSearchLoading)
        XCTAssertEqual(viewModel.items.map(\.id), [repositoryItem.id])

        await coordinator.release("query")
        await Task.yield()
        XCTAssertEqual(viewModel.items.map(\.id), [repositoryItem.id])
    }

    func testViewModelDeinit_whileSearchIsRunning_shouldReleaseViewModelAndCancelTask() async throws {
        let coordinator = ControlledViewModelSearchCoordinator()
        var viewModel: ClipboardHistoryViewModel? = ClipboardHistoryViewModel(
            repository: try testRepository(),
            writer: ClipboardWriter(restorationState: ClipboardRestorationState()),
            searchCoordinator: coordinator
        )
        weak var weakViewModel = viewModel
        await coordinator.configure(input: "pending", immediate: [], full: [])
        viewModel?.updateSearchText("pending")
        await coordinator.waitUntilStarted("pending")

        viewModel = nil

        let wasCancelled = await coordinator.waitUntilCancelled("pending")
        XCTAssertNil(weakViewModel)
        XCTAssertTrue(wasCancelled)
    }

    private func waitUntil(
        attempts: Int = 1_000,
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<attempts {
            if condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Condition did not become true")
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

private actor ControlledViewModelSearchCoordinator: SearchCoordinating {
    private struct Config {
        let immediate: [ClipboardHistoryItem]
        let full: [ClipboardHistoryItem]
        let errorDescription: String?
    }

    private var configs: [String: Config] = [:]
    private var started: Set<String> = []
    private var released: Set<String> = []
    private var cancelled: Set<String> = []

    func configure(
        input: String,
        immediate: [ClipboardHistoryItem],
        full: [ClipboardHistoryItem],
        errorDescription: String? = nil
    ) {
        configs[input] = Config(immediate: immediate, full: full, errorDescription: errorDescription)
    }

    func immediateResults(
        input: String,
        loadedItems: [ClipboardHistoryItem],
        filters: SearchUIFilters
    ) -> SearchResponse {
        response(input: input, items: configs[input]?.immediate ?? [], errorDescription: nil)
    }

    func search(
        input: String,
        loadedItems: [ClipboardHistoryItem],
        filters: SearchUIFilters
    ) async -> SearchResponse {
        started.insert(input)
        while released.contains(input) == false {
            if Task.isCancelled {
                cancelled.insert(input)
                return response(input: input, items: [], isCurrent: false, errorDescription: nil)
            }
            await Task.yield()
        }
        if Task.isCancelled {
            cancelled.insert(input)
            return response(input: input, items: [], isCurrent: false, errorDescription: nil)
        }
        let config = configs[input]
        return response(
            input: input,
            items: config?.full ?? [],
            errorDescription: config?.errorDescription
        )
    }

    func cancelCurrentSearch() {}

    func waitUntilStarted(_ input: String) async {
        while started.contains(input) == false {
            await Task.yield()
        }
    }

    func waitUntilCancelled(_ input: String, attempts: Int = 1_000) async -> Bool {
        for _ in 0..<attempts {
            if cancelled.contains(input) {
                return true
            }
            await Task.yield()
        }
        return false
    }

    func wasCancelled(_ input: String) -> Bool {
        cancelled.contains(input)
    }

    func release(_ input: String) {
        released.insert(input)
    }

    func releaseAll() {
        released.formUnion(started)
    }

    private func response(
        input: String,
        items: [ClipboardHistoryItem],
        isCurrent: Bool = true,
        errorDescription: String?
    ) -> SearchResponse {
        SearchResponse(
            parsedQuery: SearchQueryParser().parse(input),
            results: items.map { RankedSearchResult(item: $0, score: 1, matchedTerms: []) },
            isCurrent: isCurrent,
            errorDescription: errorDescription
        )
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
