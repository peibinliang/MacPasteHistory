import SQLite3
import XCTest

@testable import MacPasteHistory

final class SQLiteConcurrencyGovernanceTests: XCTestCase {
    func testCurrentJournalMode_whenWriteTransactionOverlapsReadOnlySearch_shouldReturnCommittedSnapshot() async throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let repository = ClipboardHistoryRepository(database: temporary.connection)
        _ = try repository.saveText("committed search row", sourceApp: nil, sourceBundleID: nil)
        let provider = SearchCandidateProvider(databaseURL: temporary.url)

        try temporary.connection.execute("BEGIN IMMEDIATE TRANSACTION;")
        defer { try? temporary.connection.execute("ROLLBACK;") }
        try insertRawText("uncommitted search row", hash: "uncommitted-hash", into: temporary.connection)

        let beforeCommit = try await provider.candidates(for: searchRequest("search row"))
        XCTAssertEqual(beforeCommit.map(\.textContent), ["committed search row"])

        try temporary.connection.execute("COMMIT;")
        let afterCommit = try await provider.candidates(for: searchRequest("search row"))
        XCTAssertEqual(afterCommit.map(\.textContent), ["uncommitted search row", "committed search row"])
    }

    func testCurrentJournalMode_whenSecondWriterOverlapsImmediateTransaction_shouldFailWithinBusyTimeout() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let competingWriter = try DatabaseConnection(databaseURL: temporary.url)
        defer { try? competingWriter.close() }

        try temporary.connection.execute("BEGIN IMMEDIATE TRANSACTION;")
        defer { try? temporary.connection.execute("ROLLBACK;") }

        let startedAt = Date()
        XCTAssertThrowsError(
            try competingWriter.inTransaction {
                try insertRawText("blocked writer", hash: "blocked-writer-hash", into: competingWriter)
            }
        )
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2.5)
    }

    func testCurrentJournalMode_whenTransactionRollsBackAndDatabaseReopens_shouldPersistOnlyCommittedRows() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let repository = ClipboardHistoryRepository(database: temporary.connection)
        _ = try repository.saveText("committed before rollback", sourceApp: nil, sourceBundleID: nil)

        XCTAssertThrowsError(
            try temporary.connection.inTransaction {
                try insertRawText("rolled back row", hash: "rolled-back-hash", into: temporary.connection)
                throw ExpectedRollback.rollback
            }
        )
        try temporary.connection.close()

        let reopened = try DatabaseConnection(databaseURL: temporary.url)
        defer { try? reopened.close() }
        let reopenedRepository = ClipboardHistoryRepository(database: reopened)

        XCTAssertEqual(
            try reopenedRepository.fetchHistory(query: HistoryQuery()).map(\.textContent),
            ["committed before rollback"]
        )
    }

    func testCurrentJournalMode_whenDatabaseCloses_shouldNotLeaveWALSidecars() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        XCTAssertEqual(try journalMode(in: temporary.connection), "delete")
        _ = try ClipboardHistoryRepository(database: temporary.connection)
            .saveText("sidecar check", sourceApp: nil, sourceBundleID: nil)

        try temporary.connection.close()

        XCTAssertFalse(FileManager.default.fileExists(atPath: temporary.url.path + "-wal"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporary.url.path + "-shm"))
    }

    func testSyntheticV102Build4Fixture_whenReopenedAndMigrated_shouldRetainHistoryAndUsage() throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try createRepresentativeV102Build4Fixture(at: temporary)
        try temporary.connection.close()

        let reopened = try DatabaseConnection(databaseURL: temporary.url)
        defer { try? reopened.close() }
        try MigrationManager(database: reopened).migrate()
        let repository = ClipboardHistoryRepository(database: reopened)
        let tokenUsage = AITokenUsageRepository(database: reopened)

        XCTAssertEqual(try migrationVersions(in: reopened), [1, 2, 3, 4])
        XCTAssertEqual(
            try repository.fetchHistory(query: HistoryQuery()).map(\.textContent),
            ["fixture derived", "fixture text"]
        )
        XCTAssertEqual(try tokenUsage.summary().totalTokens, 12)
    }

    func testWALExperiment_shouldPassSameReadWriteBusyRollbackReopenAndSidecarMatrix() async throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try setJournalMode("WAL", in: temporary.connection)
        try MigrationManager(database: temporary.connection).migrate()
        _ = try ClipboardHistoryRepository(database: temporary.connection).saveText(
            "wal committed snapshot",
            sourceApp: nil,
            sourceBundleID: nil
        )
        let competingWriter = try DatabaseConnection(databaseURL: temporary.url)

        try temporary.connection.execute("BEGIN IMMEDIATE TRANSACTION;")
        try insertRawText("wal rolled back", hash: "wal-rolled-back", into: temporary.connection)
        let candidates = try await SearchCandidateProvider(databaseURL: temporary.url).candidates(
            for: searchRequest("wal")
        )
        XCTAssertEqual(candidates.map(\.textContent), ["wal committed snapshot"])

        let startedAt = Date()
        XCTAssertThrowsError(
            try competingWriter.inTransaction {
                try insertRawText("wal blocked", hash: "wal-blocked", into: competingWriter)
            }
        )
        let busyWait = Date().timeIntervalSince(startedAt)
        XCTAssertGreaterThanOrEqual(busyWait, 0.8)
        XCTAssertLessThan(busyWait, 2.5)

        try temporary.connection.execute("ROLLBACK;")
        _ = try ClipboardHistoryRepository(database: competingWriter).saveText(
            "wal committed after rollback",
            sourceApp: nil,
            sourceBundleID: nil
        )
        try competingWriter.close()
        try temporary.connection.close()

        let reopened = try DatabaseConnection(databaseURL: temporary.url)
        XCTAssertEqual(try journalMode(in: reopened), "wal")
        XCTAssertEqual(
            try ClipboardHistoryRepository(database: reopened).fetchHistory(query: HistoryQuery()).map(\.textContent),
            ["wal committed after rollback", "wal committed snapshot"]
        )
        try reopened.close()
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.url.path + "-wal"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.url.path + "-shm"))
    }

    private enum ExpectedRollback: Error {
        case rollback
    }

    private func createRepresentativeV102Build4Fixture(at temporary: TemporaryDatabase) throws {
        try MigrationManager(database: temporary.connection).migrate()
        let repository = ClipboardHistoryRepository(database: temporary.connection)
        let source = try repository.saveText(
            "fixture text",
            sourceApp: "Notes",
            sourceBundleID: "com.apple.Notes",
            capturedAt: Date(timeIntervalSince1970: 1_754_000_000)
        )
        _ = try repository.saveDerivedText(DerivedClipboardRecordRequest(
            text: "fixture derived",
            sourceHistoryID: source.id,
            actionID: "text.uppercase",
            actionSummary: "Uppercase",
            sourcePreview: "fixture text",
            sourceHash: source.contentHash,
            detection: ContentClassifier().classifyFast("fixture derived")
        ))
        try AITokenUsageRepository(database: temporary.connection).insert(AITokenUsageRecord(
            requestID: "fixture-request",
            provider: "deepseek",
            modelIdentifier: "deepseek-v4-flash",
            inputTokens: 5,
            outputTokens: 7,
            totalTokens: 12,
            cachedInputTokens: nil,
            createdAt: Date(timeIntervalSince1970: 1_754_000_001)
        ))
    }

    private func insertRawText(_ text: String, hash: String, into database: DatabaseConnection) throws {
        let escapedText = text.replacingOccurrences(of: "'", with: "''")
        let escapedHash = hash.replacingOccurrences(of: "'", with: "''")
        try database.execute(
            """
            INSERT INTO clipboard_history (
                content_type, text_content, content_hash, text_length,
                searchable_text, first_captured_at, last_captured_at, capture_count
            ) VALUES (
                'text', '\(escapedText)', '\(escapedHash)', \(text.count),
                '\(escapedText)', '2026-08-12 00:00:00.000000', '2026-08-12 00:00:00.000000', 1
            );
            """
        )
    }

    private func searchRequest(_ input: String) -> SearchCandidateRequest {
        SearchCandidateRequest(
            parsedQuery: SearchQueryParser().parse(input),
            storageContentType: nil,
            sourceFilter: .all,
            timeRange: .all,
            favoritesOnly: false,
            limit: 20
        )
    }

    private func journalMode(in database: DatabaseConnection) throws -> String {
        let statement = try database.prepare("PRAGMA journal_mode;")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0) else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
        return String(cString: value)
    }

    private func setJournalMode(_ mode: String, in database: DatabaseConnection) throws {
        let statement = try database.prepare("PRAGMA journal_mode=\(mode);")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    private func migrationVersions(in database: DatabaseConnection) throws -> [Int32] {
        let statement = try database.prepare("SELECT version FROM schema_migrations ORDER BY version;")
        defer { sqlite3_finalize(statement) }
        var versions: [Int32] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            versions.append(sqlite3_column_int(statement, 0))
        }
        return versions
    }
}
