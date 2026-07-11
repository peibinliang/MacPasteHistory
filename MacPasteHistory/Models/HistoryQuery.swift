import Foundation

struct HistoryQuery {
    enum TimeRange: String, CaseIterable, Identifiable {
        case all
        case today
        case last7Days
        case last30Days

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return L10n.string("All Time")
            case .today:
                return L10n.string("Today")
            case .last7Days:
                return L10n.string("Last 7 Days")
            case .last30Days:
                return L10n.string("Last 30 Days")
            }
        }

        var startDate: Date? {
            let calendar = Calendar.current
            switch self {
            case .all:
                return nil
            case .today:
                return calendar.startOfDay(for: Date())
            case .last7Days:
                return calendar.date(byAdding: .day, value: -7, to: Date())
            case .last30Days:
                return calendar.date(byAdding: .day, value: -30, to: Date())
            }
        }
    }

    struct SourceFilter: Equatable {
        let appName: String?
        let bundleID: String?

        static let all = SourceFilter(appName: nil, bundleID: nil)

        var isAll: Bool {
            appName == nil && bundleID == nil
        }
    }

    let keyword: String?
    let favoritesOnly: Bool
    let contentType: ClipboardContentType?
    let timeRange: TimeRange
    let sourceFilter: SourceFilter
    let limit: Int
    let offset: Int

    init(
        keyword: String? = nil,
        favoritesOnly: Bool = false,
        contentType: ClipboardContentType? = nil,
        timeRange: TimeRange = .all,
        sourceFilter: SourceFilter = .all,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.keyword = keyword
        self.favoritesOnly = favoritesOnly
        self.contentType = contentType
        self.timeRange = timeRange
        self.sourceFilter = sourceFilter
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

struct HistorySourceOption: Equatable, Identifiable, Hashable {
    let appName: String?
    let bundleID: String?

    var id: String {
        bundleID ?? appName ?? "unknown"
    }

    var title: String {
        appName?.isEmpty == false ? appName! : L10n.string("Unknown Source")
    }

    var filter: HistoryQuery.SourceFilter {
        HistoryQuery.SourceFilter(appName: appName, bundleID: bundleID)
    }
}
