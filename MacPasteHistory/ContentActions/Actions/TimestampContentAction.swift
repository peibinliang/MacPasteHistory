import Foundation

struct TimestampContentAction: ContentAction {
    let id = ContentActionID(rawValue: "timestamp.convert")
    let titleKey = "timestamp.convert"
    let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [.timestamp, .plainText]
    func validate(input: String) -> ActionValidationResult { date(input) == nil ? .invalid(.invalidInput(messageKey: "content-action.timestamp.invalid")) : .valid }
    func execute(input: String) throws -> ContentActionResult {
        guard let value = date(input) else { throw ContentActionError.invalidInput(messageKey: "content-action.timestamp.invalid") }
        let isoValue = Self.makeISOFormatter().string(from: value)
        let seconds = String(Int64(value.timeIntervalSince1970))
        let milliseconds = String(Int64((value.timeIntervalSince1970 * 1_000).rounded()))
        let variants = [
            ContentActionCopyVariant(id: "local", titleKey: "local", value: Self.makeFormatter(format: "yyyy-MM-dd HH:mm:ss").string(from: value)),
            ContentActionCopyVariant(id: "utc", titleKey: "utc", value: Self.makeFormatter(
                format: "yyyy-MM-dd HH:mm:ss 'UTC'",
                timeZone: TimeZone(secondsFromGMT: 0)
            ).string(from: value)),
            ContentActionCopyVariant(id: "iso8601", titleKey: "iso8601", value: isoValue),
            ContentActionCopyVariant(id: "seconds", titleKey: "seconds", value: seconds),
            ContentActionCopyVariant(id: "milliseconds", titleKey: "milliseconds", value: milliseconds)
        ]
        return ContentActionResult(output: isoValue, syntax: .plainText, notices: [], copyVariants: variants)
    }

    private func date(_ input: String) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Double(trimmed), trimmed.count == 10 || trimmed.count == 13 {
            return Date(timeIntervalSince1970: trimmed.count == 13 ? number / 1_000 : number)
        }
        return Self.makeISOFormatter().date(from: trimmed)
            ?? Self.makeFormatter(format: "yyyy-MM-dd HH:mm:ss").date(from: trimmed)
    }

    private static func makeISOFormatter() -> ISO8601DateFormatter {
        ISO8601DateFormatter()
    }

    private static func makeFormatter(format: String, timeZone: TimeZone? = nil) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone ?? .current
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }
}
