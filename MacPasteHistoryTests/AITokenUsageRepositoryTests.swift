import XCTest
@testable import MacPasteHistory

final class AITokenUsageRepositoryTests: XCTestCase {
    private var temporary: TemporaryDatabase!
    private var repository: AITokenUsageRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporary = try TemporaryDatabase()
        try MigrationManager(database: temporary.connection).migrate()
        repository = AITokenUsageRepository(database: temporary.connection)
    }

    override func tearDownWithError() throws {
        repository = nil
        temporary.remove()
        temporary = nil
        try super.tearDownWithError()
    }

    func testInsertAndSummary_shouldAggregateProviderReportedUsage() throws {
        XCTAssertTrue(try repository.insert(makeRecord(requestID: "request-1", model: "deepseek-v4-flash")))
        XCTAssertTrue(try repository.insert(makeRecord(requestID: "request-2", model: "deepseek-v4-pro")))

        XCTAssertEqual(
            try repository.summary(),
            AITokenUsageSummary(requestCount: 2, inputTokens: 20, outputTokens: 10, totalTokens: 30, cachedInputTokens: 4)
        )
        XCTAssertEqual(try repository.summary(modelIdentifier: "deepseek-v4-flash").requestCount, 1)
    }

    func testInsert_whenRequestIDRepeats_shouldInsertExactlyOnce() throws {
        let record = makeRecord(requestID: "same-request", model: "deepseek-v4-flash")

        XCTAssertTrue(try repository.insert(record))
        XCTAssertFalse(try repository.insert(record))
        XCTAssertEqual(try repository.summary().requestCount, 1)
    }

    func testInsert_whenOptionalCacheUsageIsMissing_shouldStoreZeroInAggregate() throws {
        let record = AITokenUsageRecord(
            requestID: "no-cache", provider: "deepseek", modelIdentifier: "deepseek-v4-flash",
            inputTokens: 5, outputTokens: 3, totalTokens: 8, cachedInputTokens: nil, createdAt: Date()
        )

        XCTAssertTrue(try repository.insert(record))
        XCTAssertEqual(try repository.summary().cachedInputTokens, 0)
    }

    func testInsert_whenRecordIsInvalid_shouldRejectWithoutPartialWrite() throws {
        let invalid = AITokenUsageRecord(
            requestID: "invalid", provider: "deepseek", modelIdentifier: "deepseek-v4-flash",
            inputTokens: -1, outputTokens: 3, totalTokens: 2, cachedInputTokens: nil, createdAt: Date()
        )

        XCTAssertThrowsError(try repository.insert(invalid))
        XCTAssertEqual(try repository.summary(), .zero)
    }

    func testDeleteAll_shouldRemoveUsageRecords() throws {
        try repository.insert(makeRecord(requestID: "delete-me", model: "deepseek-v4-flash"))

        try repository.deleteAll()

        XCTAssertEqual(try repository.summary(), .zero)
    }

    private func makeRecord(requestID: String, model: String) -> AITokenUsageRecord {
        AITokenUsageRecord(
            requestID: requestID, provider: "deepseek", modelIdentifier: model,
            inputTokens: 10, outputTokens: 5, totalTokens: 15, cachedInputTokens: 2, createdAt: Date()
        )
    }
}
