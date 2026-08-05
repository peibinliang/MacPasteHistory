import XCTest
@testable import MacPasteHistory

final class CaptureEventAggregationServiceTests: XCTestCase {
    private var databaseURL: URL!
    private var database: DatabaseConnection!
    private var repository: ClipboardHistoryRepository!
    private var preferences: InMemoryCaptureEventAggregationPreferences!

    override func setUpWithError() throws {
        try super.setUpWithError()
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        database = try DatabaseConnection(databaseURL: databaseURL)
        try MigrationManager(database: database).migrate()
        repository = ClipboardHistoryRepository(database: database)
        preferences = InMemoryCaptureEventAggregationPreferences()
    }

    override func tearDownWithError() throws {
        preferences = nil
        repository = nil
        try database?.close()
        database = nil
        if let databaseURL {
            try? FileManager.default.removeItem(at: databaseURL)
        }
        databaseURL = nil
        try super.tearDownWithError()
    }

    func testCaptureSourceIdentity_shouldNormalizeBundleAppAndUnknownKeys() {
        XCTAssertEqual(
            CaptureSourceIdentity(appName: "Safari", bundleID: "COM.Apple.Safari").key,
            "bundle:com.apple.safari"
        )
        XCTAssertEqual(
            CaptureSourceIdentity(appName: "  TextEdit  ", bundleID: nil).key,
            "app:textedit"
        )
        XCTAssertEqual(CaptureSourceIdentity(appName: "  ", bundleID: nil).key, "unknown")
    }

    func testAggregateIfNeeded_shouldSummarizeOldEventsAndRetainRecentEvents() throws {
        let now = Self.date("2026-08-05 12:00:00")
        let item = try repository.saveText("aggregate source", sourceApp: nil, sourceBundleID: nil)
        try insertEvent(historyID: item.id, appName: "Safari", bundleID: "com.apple.Safari", at: "2026-07-01 09:00:00")
        try insertEvent(historyID: item.id, appName: "Safari", bundleID: "com.apple.Safari", at: "2026-07-03 11:00:00")
        try insertEvent(historyID: item.id, appName: "Notes", bundleID: "com.apple.Notes", at: "2026-07-31 11:00:00")

        try makeService().aggregateIfNeeded(now: now)

        let summaries = try repository.fetchCaptureSummaries(historyID: item.id)
        let remainingEvents = try repository.fetchCaptureEvents(historyID: item.id, since: Date(timeIntervalSince1970: 0))
        let safariSummary = try XCTUnwrap(summaries.first { $0.sourceKey == "bundle:com.apple.safari" })
        XCTAssertEqual(safariSummary.captureCount, 2)
        XCTAssertEqual(safariSummary.firstCapturedAt, Self.date("2026-07-01 09:00:00"))
        XCTAssertEqual(safariSummary.lastCapturedAt, Self.date("2026-07-03 11:00:00"))
        XCTAssertEqual(remainingEvents.filter { $0.sourceBundleID == "com.apple.Safari" }.count, 0)
        XCTAssertEqual(remainingEvents.filter { $0.sourceBundleID == "com.apple.Notes" }.count, 1)
        XCTAssertEqual(preferences.lastAggregationDate, now)
    }

    func testAggregateIfNeeded_whenRunAgainOnAnotherDay_shouldNotDoubleCountSummaries() throws {
        let firstRun = Self.date("2026-08-05 12:00:00")
        let item = try repository.saveText("idempotent aggregate", sourceApp: nil, sourceBundleID: nil)
        try insertEvent(historyID: item.id, appName: "Safari", bundleID: "com.apple.Safari", at: "2026-07-01 09:00:00")

        try makeService().aggregateIfNeeded(now: firstRun)
        try makeService().aggregateIfNeeded(now: Self.date("2026-08-06 12:00:00"))

        let summaries = try repository.fetchCaptureSummaries(historyID: item.id)
        XCTAssertEqual(summaries.first?.captureCount, 1)
    }

    func testAggregateIfNeeded_whenEventDeleteFails_shouldRollBackSummaryAndKeepPreferenceUnset() throws {
        let now = Self.date("2026-08-05 12:00:00")
        let item = try repository.saveText("rollback aggregate", sourceApp: nil, sourceBundleID: nil)
        try insertEvent(historyID: item.id, appName: "Safari", bundleID: "com.apple.Safari", at: "2026-07-01 09:00:00")
        try database.execute("""
        CREATE TRIGGER fail_capture_event_delete
        BEFORE DELETE ON clipboard_capture_events
        BEGIN
            SELECT RAISE(ABORT, 'capture event delete failure');
        END;
        """)

        XCTAssertThrowsError(try makeService().aggregateIfNeeded(now: now))

        XCTAssertTrue(try repository.fetchCaptureSummaries(historyID: item.id).isEmpty)
        XCTAssertEqual(
            try repository.fetchCaptureEvents(historyID: item.id, since: Date(timeIntervalSince1970: 0))
                .filter { $0.sourceBundleID == "com.apple.Safari" }.count,
            1
        )
        XCTAssertNil(preferences.lastAggregationDate)
    }

    func testAggregateIfNeeded_whenAlreadyAggregatedToday_shouldLeaveOldEventsUnchanged() throws {
        let now = Self.date("2026-08-05 12:00:00")
        preferences.lastAggregationDate = Self.date("2026-08-05 01:00:00")
        let item = try repository.saveText("same-day aggregate", sourceApp: nil, sourceBundleID: nil)
        try insertEvent(historyID: item.id, appName: "Safari", bundleID: "com.apple.Safari", at: "2026-07-01 09:00:00")

        try makeService().aggregateIfNeeded(now: now)

        XCTAssertTrue(try repository.fetchCaptureSummaries(historyID: item.id).isEmpty)
        XCTAssertEqual(
            try repository.fetchCaptureEvents(historyID: item.id, since: Date(timeIntervalSince1970: 0))
                .filter { $0.sourceBundleID == "com.apple.Safari" }.count,
            1
        )
    }

    private func makeService() -> CaptureEventAggregationService {
        CaptureEventAggregationService(repository: repository, preferences: preferences, calendar: Self.calendar)
    }

    private func insertEvent(historyID: Int64, appName: String, bundleID: String, at timestamp: String) throws {
        try database.execute("""
        INSERT INTO clipboard_capture_events (history_id, source_app, source_bundle_id, captured_at)
        VALUES (\(historyID), '\(appName)', '\(bundleID)', '\(timestamp)');
        """)
    }

    private static let calendar = Calendar(identifier: .gregorian)

    private static func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = formatter.date(from: value) else {
            fatalError("Invalid test date")
        }
        return date
    }
}

private final class InMemoryCaptureEventAggregationPreferences: CaptureEventAggregationPreferencesProviding {
    var lastAggregationDate: Date?
}
