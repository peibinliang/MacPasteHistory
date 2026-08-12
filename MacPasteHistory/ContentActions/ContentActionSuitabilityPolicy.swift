import Foundation

struct ContentActionSuitabilityPolicy {
    private static let plainTextActionIDs: Set<String> = [
        "text.trim",
        "text.remove-empty-lines",
        "text.deduplicate-lines",
        "text.single-line",
        "text.uppercase",
        "text.lowercase",
        "text.markdown-code-block",
        "ai.polish-text",
        "json.escape",
        "url.encode-query-value",
        "base64.encode",
        "shell.quote-argument"
    ]

    func isSuitable(_ action: any ContentAction, for type: DetectedContentType) -> Bool {
        let actionID = action.id.rawValue
        if actionID == AITextTranslationAction.actionID.rawValue {
            return type != .image
        }
        return switch type {
        case .plainText:
            Self.plainTextActionIDs.contains(actionID)
        case .image:
            actionID == "base64.encode"
        case .json:
            actionID.hasPrefix("json.")
        case .url:
            actionID.hasPrefix("url.")
        case .base64:
            actionID.hasPrefix("base64.")
        case .jwt:
            actionID == "jwt.inspect"
        case .timestamp:
            actionID == "timestamp.convert"
        case .sql:
            actionID == "sql.single-line"
        case .shell:
            actionID == "shell.quote-argument"
        }
    }
}
