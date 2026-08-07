import Foundation

struct TimestampContentAction: ContentAction {
    let id = ContentActionID(rawValue: "timestamp.convert")
    let titleKey = "timestamp.convert"
    let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [.timestamp, .plainText]

    func validate(input: String) -> ActionValidationResult {
        date(input) == nil
            ? .invalid(.invalidInput(messageKey: "content-action.timestamp.invalid"))
            : .valid
    }

    func execute(input: String) throws -> ContentActionResult {
        guard let value = date(input) else {
            throw ContentActionError.invalidInput(messageKey: "content-action.timestamp.invalid")
        }

        let iso = ISO8601DateFormatter()
        let seconds = String(Int64(value.timeIntervalSince1970))
        let milliseconds = String(Int64(value.timeIntervalSince1970 * 1_000))
        let utc = DateFormatter()
        utc.locale = Locale(identifier: "en_US_POSIX")
        utc.timeZone = TimeZone(secondsFromGMT: 0)
        utc.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = .current
        local.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let variants = [
            ContentActionCopyVariant(id: "local", titleKey: "local", value: local.string(from: value)),
            ContentActionCopyVariant(id: "utc", titleKey: "utc", value: utc.string(from: value)),
            ContentActionCopyVariant(id: "iso8601", titleKey: "iso8601", value: iso.string(from: value)),
            ContentActionCopyVariant(id: "seconds", titleKey: "seconds", value: seconds),
            ContentActionCopyVariant(id: "milliseconds", titleKey: "milliseconds", value: milliseconds)
        ]
        return ContentActionResult(output: iso.string(from: value), syntax: .plainText, notices: [], copyVariants: variants)
    }

    private func date(_ input: String) -> Date? {
        if (input.count == 10 || input.count == 13), input.allSatisfy(\.isNumber), let number = Double(input) {
            return Date(timeIntervalSince1970: input.count == 13 ? number / 1_000 : number)
        }
        if let isoDate = ISO8601DateFormatter().date(from: input) {
            return isoDate
        }
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = .current
        local.dateFormat = "yyyy-MM-dd HH:mm:ss"
        local.isLenient = false
        return local.date(from: input)
    }
}
