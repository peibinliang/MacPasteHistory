import XCTest
@testable import MacPasteHistory

final class HistoryDisplayFormatterTests: XCTestCase {
    func testTimelineSections_shouldGroupRecentTodayAndEarlierItemsInDisplayOrder() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 12)))
        let recent = makeItem(id: 1, createdAt: now.addingTimeInterval(-60))
        let today = makeItem(id: 2, createdAt: now.addingTimeInterval(-3_600))
        let earlier = makeItem(id: 3, createdAt: now.addingTimeInterval(-86_400))

        let sections = HistoryTimelineOrganizer(calendar: calendar).sections(
            for: [recent, today, earlier],
            now: now
        )

        XCTAssertEqual(sections.map(\.group), [.recent, .today, .earlier])
        XCTAssertEqual(sections.map { $0.items.map(\.id) }, [[1], [2], [3]])
    }

    func testTimelineSections_whenGroupIsEmpty_shouldOmitIt() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 12)))
        let today = makeItem(id: 1, createdAt: now.addingTimeInterval(-3_600))

        let sections = HistoryTimelineOrganizer(calendar: calendar).sections(for: [today], now: now)

        XCTAssertEqual(sections.map(\.group), [.today])
    }

    func testRecentSources_shouldDeduplicateSourcesAndPreserveNewestOrder() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            makeItem(id: 1, sourceApp: "Xcode", sourceBundleID: "com.apple.dt.Xcode", createdAt: now),
            makeItem(id: 2, sourceApp: "Safari", sourceBundleID: "com.apple.Safari", createdAt: now.addingTimeInterval(-10)),
            makeItem(id: 3, sourceApp: "Xcode", sourceBundleID: "com.apple.dt.Xcode", createdAt: now.addingTimeInterval(-20)),
            makeItem(id: 4, sourceApp: nil, sourceBundleID: nil, createdAt: now.addingTimeInterval(-30))
        ]

        let sources = HistoryTimelineOrganizer().recentSources(from: items, limit: 5)

        XCTAssertEqual(sources.map(\.title), ["Xcode", "Safari"])
        XCTAssertEqual(sources.map(\.bundleID), ["com.apple.dt.Xcode", "com.apple.Safari"])
    }

    func testPreview_whenTextIsLong_shouldReturnBoundedMultiLinePreview() {
        let formatter = HistoryDisplayFormatter()
        let longText = Array(repeating: "line", count: 20).joined(separator: "\n")

        let preview = formatter.preview(for: longText)

        XCTAssertLessThanOrEqual(preview.components(separatedBy: "\n").count, 3)
        XCTAssertTrue(preview.hasSuffix("..."))
    }

    func testPreview_whenTextIsShort_shouldReturnOriginalText() {
        let formatter = HistoryDisplayFormatter()

        let preview = formatter.preview(for: "short text")

        XCTAssertEqual(preview, "short text")
    }

    func testDisplayTime_whenDateIsToday_shouldShowTodayAndTime() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 15)))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 9, minute: 30)))
        let formatter = HistoryDisplayFormatter(calendar: calendar)

        let displayTime = formatter.displayTime(for: date, now: now)

        XCTAssertEqual(displayTime, "\(NSLocalizedString("Today", comment: "")) 09:30")
    }

    func testDisplayTime_whenDateIsYesterday_shouldShowYesterdayAndTime() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 15)))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 22, minute: 15)))
        let formatter = HistoryDisplayFormatter(calendar: calendar)

        let displayTime = formatter.displayTime(for: date, now: now)

        XCTAssertEqual(displayTime, "\(NSLocalizedString("Yesterday", comment: "")) 22:15")
    }

    func testDisplayTime_whenDateIsOlder_shouldShowExactDateAndTime() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 15)))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 8, minute: 5)))
        let formatter = HistoryDisplayFormatter(calendar: calendar)
        let expectedFormatter = DateFormatter()
        expectedFormatter.locale = Locale.current
        expectedFormatter.calendar = calendar
        expectedFormatter.dateStyle = .medium
        expectedFormatter.timeStyle = .short

        let displayTime = formatter.displayTime(for: date, now: now)

        XCTAssertEqual(displayTime, expectedFormatter.string(from: date))
    }

    private func makeItem(
        id: Int64,
        sourceApp: String? = "TextEdit",
        sourceBundleID: String? = "com.apple.TextEdit",
        createdAt: Date
    ) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: id,
            contentType: .text,
            textContent: "Sample \(id)",
            filePath: nil,
            thumbnailPath: nil,
            sourceApp: sourceApp,
            sourceBundleID: sourceBundleID,
            contentHash: "hash-\(id)",
            textLength: 8,
            fileSize: nil,
            imageWidth: nil,
            imageHeight: nil,
            imageFormat: nil,
            isFavorite: false,
            isSensitive: false,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
