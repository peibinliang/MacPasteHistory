import Foundation

struct ContentActionCopyVariant: Identifiable, Equatable, Sendable {
    let id: String
    let titleKey: String
    let value: String
}
struct ContentActionNotice: Equatable, Sendable { let messageKey: String }
struct ContentActionResult: Equatable, Sendable {
    let output: String
    let syntax: ContentSyntax
    let notices: [ContentActionNotice]
    let copyVariants: [ContentActionCopyVariant]
    let aiTokenUsage: DeepSeekTokenUsage?
    let isAIUsageUnavailable: Bool

    init(
        output: String,
        syntax: ContentSyntax,
        notices: [ContentActionNotice],
        copyVariants: [ContentActionCopyVariant],
        aiTokenUsage: DeepSeekTokenUsage? = nil,
        isAIUsageUnavailable: Bool = false
    ) {
        self.output = output
        self.syntax = syntax
        self.notices = notices
        self.copyVariants = copyVariants
        self.aiTokenUsage = aiTokenUsage
        self.isAIUsageUnavailable = isAIUsageUnavailable
    }
}
