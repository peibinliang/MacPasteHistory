import Foundation

struct AITextPolishingAction: AsyncContentAction {
    static let actionID = ContentActionID(rawValue: "ai.polish-text")

    let service: any AITextPolishingServing
    let id = actionID
    let titleKey = "ai.action.polish"
    let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [
        .plainText, .json, .url, .base64, .jwt, .timestamp, .sql, .shell
    ]

    func validate(input: String) -> ActionValidationResult {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .invalid(.invalidInput(messageKey: "ai.error.invalid-input"))
            : .valid
    }

    func execute(input: String) throws -> ContentActionResult {
        throw ContentActionError.unsupportedInput(messageKey: "content-action.unsupported")
    }

    func executeAsync(input: String) async throws -> ContentActionResult {
        let outcome = try await service.polish(input)
        var notices: [ContentActionNotice] = []
        if outcome.usagePersistenceFailed {
            notices.append(ContentActionNotice(messageKey: "ai.usage.persistence-failed"))
        }
        return ContentActionResult(
            output: outcome.text,
            syntax: .plainText,
            notices: notices,
            copyVariants: [],
            aiTokenUsage: outcome.usage,
            isAIUsageUnavailable: outcome.usage == nil
        )
    }
}
