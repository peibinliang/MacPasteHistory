import Foundation

struct AITokenUsageRecord: Equatable, Sendable {
    let requestID: String
    let provider: String
    let modelIdentifier: String
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let cachedInputTokens: Int?
    let createdAt: Date
}

struct AITokenUsageSummary: Equatable, Sendable {
    static let zero = AITokenUsageSummary(
        requestCount: 0,
        inputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
        cachedInputTokens: 0
    )

    let requestCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let cachedInputTokens: Int
}
