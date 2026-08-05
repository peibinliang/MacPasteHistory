import Foundation

protocol CaptureEventAggregationPreferencesProviding: AnyObject {
    var lastAggregationDate: Date? { get set }
}

final class CaptureEventAggregationPreferences: CaptureEventAggregationPreferencesProviding {
    private static let lastAggregationDateKey = "captureEventAggregation.lastAggregationDate"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastAggregationDate: Date? {
        get { defaults.object(forKey: Self.lastAggregationDateKey) as? Date }
        set { defaults.set(newValue, forKey: Self.lastAggregationDateKey) }
    }
}
