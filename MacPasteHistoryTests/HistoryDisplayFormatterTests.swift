import XCTest
@testable import MacPasteHistory

final class HistoryDisplayFormatterTests: XCTestCase {
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

        XCTAssertEqual(displayTime, "Today 09:30")
    }

    func testDisplayTime_whenDateIsYesterday_shouldShowYesterdayAndTime() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 15)))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 22, minute: 15)))
        let formatter = HistoryDisplayFormatter(calendar: calendar)

        let displayTime = formatter.displayTime(for: date, now: now)

        XCTAssertEqual(displayTime, "Yesterday 22:15")
    }

    func testDisplayTime_whenDateIsOlder_shouldShowExactDateAndTime() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 15)))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 8, minute: 5)))
        let formatter = HistoryDisplayFormatter(calendar: calendar)

        let displayTime = formatter.displayTime(for: date, now: now)

        XCTAssertEqual(displayTime, "2026-06-28 08:05")
    }
}
