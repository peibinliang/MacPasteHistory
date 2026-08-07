import XCTest

@testable import MacPasteHistory

final class SearchCoordinatorTests: XCTestCase {
    func testImmediateResults_appliesExistingRibbonFiltersWithoutAwaitingCandidateProvider() async {
        let provider = ControlledCandidateProvider()
        let coordinator = SearchCoordinator(provider: provider)
        let terminal = item(id: 1, text: "needle terminal", sourceApp: "Terminal", isFavorite: true)
        let notes = item(id: 2, text: "needle notes", sourceApp: "Notes", isFavorite: false)
        let filters = SearchUIFilters(
            selectedSourceOption: HistorySourceOption(appName: "Terminal", bundleID: nil),
            isFavoritesOnly: true
        )

        let response = await coordinator.immediateResults(
            input: "needle",
            loadedItems: [terminal, notes],
            filters: filters
        )
        let requestCount = await provider.requestCount()

        XCTAssertTrue(response.isCurrent)
        XCTAssertEqual(response.results.map(\.id), [terminal.id])
        XCTAssertEqual(requestCount, 0)
    }

    func testSearch_returnsOnlyNewestGenerationAsCurrentWhenOlderQueryFinishesLast() async throws {
        let provider = ControlledCandidateProvider()
        let sleeper = ControlledSearchSleeper()
        let coordinator = SearchCoordinator(provider: provider, sleeper: sleeper)
        let filters = SearchUIFilters()

        let first = Task { await coordinator.search(input: "j", loadedItems: [], filters: filters) }
        await sleeper.waitForSleepCount(1)
        await sleeper.resumeNext()
        await provider.waitForRequestCount(1)

        let second = Task { await coordinator.search(input: "json", loadedItems: [], filters: filters) }
        await sleeper.waitForSleepCount(1)
        await sleeper.resumeNext()
        await provider.waitForRequestCount(2)

        await provider.resume(query: "json", with: [item(id: 2, text: "json document")])
        let newest = await second.value
        await provider.resume(query: "j", with: [item(id: 1, text: "java document")])
        let oldest = await first.value

        XCTAssertTrue(newest.isCurrent)
        XCTAssertEqual(newest.parsedQuery.rawInput, "json")
        XCTAssertFalse(oldest.isCurrent)
    }

    func testCancelCurrentSearch_invalidatesDebouncedRequestAndUsesInjectedDelay() async {
        let provider = ControlledCandidateProvider()
        let sleeper = ControlledSearchSleeper()
        let coordinator = SearchCoordinator(provider: provider, sleeper: sleeper)
        let task = Task { await coordinator.search(input: "cancel", loadedItems: [], filters: SearchUIFilters()) }

        await sleeper.waitForSleepCount(1)
        await coordinator.cancelCurrentSearch()
        await sleeper.resumeAll()
        let response = await task.value
        let delays = await sleeper.requestedDelays()
        let requestCount = await provider.requestCount()

        XCTAssertFalse(response.isCurrent)
        XCTAssertEqual(delays, [0.15])
        XCTAssertEqual(requestCount, 0)
    }

    private func item(
        id: Int64,
        text: String,
        sourceApp: String? = nil,
        isFavorite: Bool = false
    ) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: id,
            contentType: .text,
            textContent: text,
            filePath: nil,
            thumbnailPath: nil,
            sourceApp: sourceApp,
            sourceBundleID: nil,
            contentHash: "hash-\(id)",
            textLength: text.count,
            fileSize: nil,
            imageWidth: nil,
            imageHeight: nil,
            imageFormat: nil,
            isFavorite: isFavorite,
            isSensitive: false,
            createdAt: Date(),
            updatedAt: Date(),
            searchableText: text
        )
    }
}

private actor ControlledCandidateProvider: SearchCandidateProviding {
    private var continuations: [String: CheckedContinuation<[ClipboardHistoryItem], Error>] = [:]

    func candidates(for request: SearchCandidateRequest) async throws -> [ClipboardHistoryItem] {
        try await withCheckedThrowingContinuation { continuation in
            continuations[request.parsedQuery.rawInput] = continuation
        }
    }

    func waitForRequestCount(_ expectedCount: Int) async {
        while continuations.count < expectedCount {
            await Task.yield()
        }
    }

    func resume(query: String, with items: [ClipboardHistoryItem]) {
        continuations.removeValue(forKey: query)?.resume(returning: items)
    }

    func requestCount() -> Int {
        continuations.count
    }
}

private actor ControlledSearchSleeper: SearchSleeping {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var delays: [TimeInterval] = []

    func sleep(for delay: TimeInterval) async {
        delays.append(delay)
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForSleepCount(_ expectedCount: Int) async {
        while continuations.count < expectedCount {
            await Task.yield()
        }
    }

    func resumeAll() {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }

    func resumeNext() {
        guard continuations.isEmpty == false else { return }
        continuations.removeFirst().resume()
    }

    func requestedDelays() -> [TimeInterval] {
        delays
    }
}
