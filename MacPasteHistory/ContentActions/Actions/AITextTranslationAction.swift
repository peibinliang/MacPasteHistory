import Foundation

struct AITextTranslationAction: RemoteAIContentAction {
    static let actionID = ContentActionID(rawValue: "ai.translate-text")

    let service: any AITextTranslationServing
    let id = actionID
    let titleKey = "ai.action.translate"
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
        let outcome = try await service.translate(input)
        let notices = outcome.usagePersistenceFailed
            ? [ContentActionNotice(messageKey: "ai.usage.persistence-failed")]
            : []
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
