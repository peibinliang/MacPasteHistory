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

enum HistoryTimelineGroup: Int, CaseIterable, Equatable {
    case recent
    case today
    case earlier

    var title: String {
        switch self {
        case .recent:
            return L10n.string("Just Now")
        case .today:
            return L10n.string("Today")
        case .earlier:
            return L10n.string("Earlier")
        }
    }
}

struct HistoryTimelineSection: Identifiable, Equatable {
    let group: HistoryTimelineGroup
    let items: [ClipboardHistoryItem]

    var id: HistoryTimelineGroup {
        group
    }
}

struct HistoryRecentSource: Identifiable, Equatable {
    let title: String
    let bundleID: String
    let lastUsedAt: Date

    var id: String {
        bundleID
    }
}

struct HistoryTimelineOrganizer {
    private let calendar: Calendar
    private let recentInterval: TimeInterval

    init(calendar: Calendar = .current, recentInterval: TimeInterval = 10 * 60) {
        self.calendar = calendar
        self.recentInterval = recentInterval
    }

    func sections(
        for items: [ClipboardHistoryItem],
        now: Date = Date()
    ) -> [HistoryTimelineSection] {
        let groupedItems = Dictionary(grouping: items) { item in
            group(for: item.createdAt, now: now)
        }

        return HistoryTimelineGroup.allCases.compactMap { group in
            guard let items = groupedItems[group], items.isEmpty == false else {
                return nil
            }
            return HistoryTimelineSection(group: group, items: items)
        }
    }

    func recentSources(
        from items: [ClipboardHistoryItem],
        limit: Int
    ) -> [HistoryRecentSource] {
        guard limit > 0 else {
            return []
        }

        var seenBundleIDs = Set<String>()
        var sources: [HistoryRecentSource] = []

        for item in items {
            guard let title = item.sourceApp?.trimmingCharacters(in: .whitespacesAndNewlines),
                  title.isEmpty == false,
                  let bundleID = item.sourceBundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  bundleID.isEmpty == false,
                  seenBundleIDs.insert(bundleID).inserted else {
                continue
            }

            sources.append(
                HistoryRecentSource(
                    title: title,
                    bundleID: bundleID,
                    lastUsedAt: item.createdAt
                )
            )
            if sources.count == limit {
                break
            }
        }

        return sources
    }

    private func group(for date: Date, now: Date) -> HistoryTimelineGroup {
        if now.timeIntervalSince(date) >= 0,
           now.timeIntervalSince(date) <= recentInterval {
            return .recent
        }
        if calendar.isDate(date, inSameDayAs: now) {
            return .today
        }
        return .earlier
    }
}
