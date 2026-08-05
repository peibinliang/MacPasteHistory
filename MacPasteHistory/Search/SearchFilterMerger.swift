import Foundation

struct SearchUIFilters: Equatable {
    let selectedSourceOption: HistorySourceOption?
    let selectedContentType: ClipboardContentType?
    let isFavoritesOnly: Bool
    let selectedTimeRange: HistoryQuery.TimeRange

    init(
        selectedSourceOption: HistorySourceOption? = nil,
        selectedContentType: ClipboardContentType? = nil,
        isFavoritesOnly: Bool = false,
        selectedTimeRange: HistoryQuery.TimeRange = .all
    ) {
        self.selectedSourceOption = selectedSourceOption
        self.selectedContentType = selectedContentType
        self.isFavoritesOnly = isFavoritesOnly
        self.selectedTimeRange = selectedTimeRange
    }
}

struct MergedSearchFilters: Equatable {
    let sourceFilter: HistoryQuery.SourceFilter
    let storageContentType: ClipboardContentType?
    let favoritesOnly: Bool
    let timeRange: HistoryQuery.TimeRange
}

struct SearchFilterMerger {
    func merge(parsedQuery: ParsedSearchQuery, controls: SearchUIFilters) -> MergedSearchFilters {
        MergedSearchFilters(
            sourceFilter: parsedQuery.app.map { HistoryQuery.SourceFilter(appName: $0, bundleID: nil) }
                ?? controls.selectedSourceOption?.filter
                ?? .all,
            storageContentType: parsedQuery.type.map(storageContentType(for:)) ?? controls.selectedContentType,
            favoritesOnly: parsedQuery.favorite ?? controls.isFavoritesOnly,
            timeRange: parsedQuery.before == nil && parsedQuery.after == nil ? controls.selectedTimeRange : .all
        )
    }

    private func storageContentType(for type: DetectedContentType) -> ClipboardContentType? {
        switch type {
        case .plainText:
            return .text
        case .image:
            return .image
        default:
            return nil
        }
    }
}
