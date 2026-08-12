import Foundation

struct SearchCandidateRequest: Equatable {
    let parsedQuery: ParsedSearchQuery
    let storageContentType: ClipboardContentType?
    let sourceFilter: HistoryQuery.SourceFilter
    let timeRange: HistoryQuery.TimeRange
    let favoritesOnly: Bool
    let favoriteFilter: Bool?
    let limit: Int

    init(
        parsedQuery: ParsedSearchQuery,
        storageContentType: ClipboardContentType?,
        sourceFilter: HistoryQuery.SourceFilter,
        timeRange: HistoryQuery.TimeRange,
        favoritesOnly: Bool,
        limit: Int
    ) {
        self.parsedQuery = parsedQuery
        self.storageContentType = storageContentType
        self.sourceFilter = sourceFilter
        self.timeRange = timeRange
        self.favoritesOnly = favoritesOnly
        favoriteFilter = parsedQuery.favorite ?? (favoritesOnly ? true : nil)
        self.limit = max(1, min(limit, 500))
    }
}

struct SearchCandidateSQL: Equatable {
    let sql: String
    let bindings: [SearchCandidateSQLBinding]
}

enum SearchCandidateSQLBinding: Equatable {
    case text(String)
    case date(Date)
    case integer(Int)
}

struct SearchCandidateSQLBuilder {
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func build(request: SearchCandidateRequest) -> SearchCandidateSQL {
        var conditions: [String] = []
        var conditionBindings: [SearchCandidateSQLBinding] = []

        appendStorageContentTypeCondition(for: request, to: &conditions, bindings: &conditionBindings)
        appendEffectiveTypeCondition(for: request, to: &conditions, bindings: &conditionBindings)
        appendTermConditions(for: request.parsedQuery.terms, to: &conditions, bindings: &conditionBindings)
        appendFavoriteCondition(for: request, to: &conditions)
        appendDateConditions(for: request, to: &conditions, bindings: &conditionBindings)
        appendSourceCondition(for: request, to: &conditions, bindings: &conditionBindings)

        var keywordBindings: [SearchCandidateSQLBinding] = []
        let keywordBucketExpression = keywordBucketExpression(for: request.parsedQuery.terms, bindings: &keywordBindings)
        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        var bindings = keywordBindings + conditionBindings
        bindings.append(.integer(request.limit))
        let selectSQL = ClipboardHistoryRepository.selectHistorySQL.replacingOccurrences(
            of: "\nFROM clipboard_history",
            with: ",\n    \(keywordBucketExpression) AS keyword_bucket\nFROM clipboard_history"
        )

        return SearchCandidateSQL(
            sql: """
            \(selectSQL)
            \(whereClause)
            ORDER BY keyword_bucket ASC, last_captured_at DESC, id DESC
            LIMIT ?;
            """,
            bindings: bindings
        )
    }

    private func appendStorageContentTypeCondition(
        for request: SearchCandidateRequest,
        to conditions: inout [String],
        bindings: inout [SearchCandidateSQLBinding]
    ) {
        guard let storageContentType = request.storageContentType else { return }
        conditions.append("content_type = ?")
        bindings.append(.text(storageContentType.rawValue))
    }

    private func appendEffectiveTypeCondition(
        for request: SearchCandidateRequest,
        to conditions: inout [String],
        bindings: inout [SearchCandidateSQLBinding]
    ) {
        guard let type = request.parsedQuery.type, type != .image else { return }
        conditions.append("\(Self.effectiveTypeExpression) = ?")
        bindings.append(.text(type.rawValue))
    }

    private func appendTermConditions(
        for terms: [String],
        to conditions: inout [String],
        bindings: inout [SearchCandidateSQLBinding]
    ) {
        for term in terms where term.isEmpty == false {
            conditions.append("\(Self.searchableTextExpression) LIKE ? COLLATE NOCASE")
            bindings.append(.text("%\(term)%"))
        }
    }

    private func appendFavoriteCondition(for request: SearchCandidateRequest, to conditions: inout [String]) {
        guard let favoriteFilter = request.favoriteFilter else { return }
        conditions.append("is_favorite = \(favoriteFilter ? 1 : 0)")
    }

    private func appendDateConditions(
        for request: SearchCandidateRequest,
        to conditions: inout [String],
        bindings: inout [SearchCandidateSQLBinding]
    ) {
        if let after = request.parsedQuery.after {
            conditions.append("julianday(last_captured_at) >= julianday(?)")
            bindings.append(.date(after))
        }
        if let before = request.parsedQuery.before {
            conditions.append("julianday(last_captured_at) <= julianday(?)")
            bindings.append(.date(before))
        }
        guard request.parsedQuery.before == nil, request.parsedQuery.after == nil,
              let startDate = timeRangeStartDate(for: request.timeRange) else {
            return
        }
        conditions.append("julianday(last_captured_at) >= julianday(?)")
        bindings.append(.date(startDate))
    }

    private func appendSourceCondition(
        for request: SearchCandidateRequest,
        to conditions: inout [String],
        bindings: inout [SearchCandidateSQLBinding]
    ) {
        guard request.sourceFilter.isAll == false else { return }
        var sourceConditions: [String] = []
        if let appName = request.sourceFilter.appName, appName.isEmpty == false {
            sourceConditions.append("LOWER(COALESCE(source_app, '')) LIKE LOWER(?)")
            sourceConditions.append("LOWER(COALESCE(source_bundle_id, '')) LIKE LOWER(?)")
            bindings.append(.text("%\(appName)%"))
            bindings.append(.text("%\(appName)%"))
        }
        if let bundleID = request.sourceFilter.bundleID, bundleID.isEmpty == false {
            sourceConditions.append("LOWER(COALESCE(source_bundle_id, '')) LIKE LOWER(?)")
            bindings.append(.text("%\(bundleID)%"))
        }
        guard sourceConditions.isEmpty == false else { return }
        conditions.append("(\(sourceConditions.joined(separator: " OR ")))")
    }

    private func keywordBucketExpression(
        for terms: [String],
        bindings: inout [SearchCandidateSQLBinding]
    ) -> String {
        guard let firstTerm = terms.first(where: { $0.isEmpty == false }) else {
            return "0"
        }
        bindings.append(.text(firstTerm))
        bindings.append(.text("%\(firstTerm)%"))
        return """
        CASE
            WHEN \(Self.searchableTextExpression) = ? COLLATE NOCASE THEN 0
            WHEN \(Self.searchableTextExpression) LIKE ? COLLATE NOCASE THEN 1
            ELSE 2
        END
        """
    }

    private func timeRangeStartDate(for range: HistoryQuery.TimeRange) -> Date? {
        let calendar = Calendar.current
        let referenceDate = now()
        switch range {
        case .all:
            return nil
        case .today:
            return calendar.startOfDay(for: referenceDate)
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: referenceDate)
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: referenceDate)
        }
    }

    private static let searchableTextExpression = "COALESCE(searchable_text, text_content, ocr_text, '')"
    private static let effectiveTypeExpression = "COALESCE(user_override_type, detected_type, CASE WHEN content_type = 'image' THEN 'image' ELSE 'plainText' END)"
}
