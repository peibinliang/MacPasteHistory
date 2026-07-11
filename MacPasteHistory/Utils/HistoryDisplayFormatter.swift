import Foundation

final class HistoryDisplayFormatter {
    private let calendar: Calendar
    private let timeFormatter: DateFormatter
    private let dateTimeFormatter: DateFormatter
    private let maxPreviewLines: Int
    private let maxPreviewCharacters: Int

    init(
        calendar: Calendar = .current,
        maxPreviewLines: Int = 3,
        maxPreviewCharacters: Int = 180
    ) {
        self.calendar = calendar
        self.maxPreviewLines = maxPreviewLines
        self.maxPreviewCharacters = maxPreviewCharacters
        self.timeFormatter = DateFormatter()
        self.timeFormatter.locale = Locale.current
        self.timeFormatter.calendar = calendar
        self.timeFormatter.dateFormat = "HH:mm"
        self.dateTimeFormatter = DateFormatter()
        self.dateTimeFormatter.locale = Locale.current
        self.dateTimeFormatter.calendar = calendar
        self.dateTimeFormatter.dateStyle = .medium
        self.dateTimeFormatter.timeStyle = .short
    }

    func preview(for text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let boundedLines = Array(lines.prefix(maxPreviewLines))
        var preview = boundedLines.joined(separator: "\n")
        var didTruncate = lines.count > maxPreviewLines

        if preview.count > maxPreviewCharacters {
            preview = String(preview.prefix(maxPreviewCharacters))
            didTruncate = true
        }

        return didTruncate ? preview.trimmingCharacters(in: .whitespacesAndNewlines) + "..." : preview
    }

    func displayTime(for date: Date, now: Date = Date()) -> String {
        let time = timeFormatter.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) {
            return "\(L10n.string("Today")) \(time)"
        }

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
            return dateTimeFormatter.string(from: date)
        }

        if calendar.isDate(date, inSameDayAs: yesterday) {
            return "\(L10n.string("Yesterday")) \(time)"
        }

        return dateTimeFormatter.string(from: date)
    }
}
