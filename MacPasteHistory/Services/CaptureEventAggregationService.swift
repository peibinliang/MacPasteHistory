import Foundation

struct CaptureEventAggregationService {
    private let repository: ClipboardHistoryRepository
    private let preferences: CaptureEventAggregationPreferencesProviding
    private let calendar: Calendar

    init(
        repository: ClipboardHistoryRepository,
        preferences: CaptureEventAggregationPreferencesProviding = CaptureEventAggregationPreferences(),
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.preferences = preferences
        self.calendar = calendar
    }

    func aggregateIfNeeded(now: Date = Date()) throws {
        if let lastAggregationDate, calendar.isDate(lastAggregationDate, inSameDayAs: now) {
            return
        }
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -DefaultSettings.captureEventAggregationRetentionDays,
            to: now
        ) else {
            throw CaptureEventAggregationError.couldNotCalculateCutoff
        }
        try repository.aggregateCaptureEvents(before: cutoff)
        preferences.lastAggregationDate = now
    }

    private var lastAggregationDate: Date? {
        preferences.lastAggregationDate
    }
}

enum CaptureEventAggregationError: LocalizedError {
    case couldNotCalculateCutoff

    var errorDescription: String? {
        "Could not calculate capture event aggregation cutoff date."
    }
}
