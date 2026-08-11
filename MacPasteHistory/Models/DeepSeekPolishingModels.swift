import Foundation

struct DeepSeekTokenUsage: Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let cachedInputTokens: Int?
}

struct DeepSeekPolishingResult: Equatable, Sendable {
    let requestID: String
    let modelIdentifier: String
    let polishedText: String
    let usage: DeepSeekTokenUsage?
}

enum DeepSeekClientError: Error, Equatable, Sendable {
    case invalidInput
    case invalidRequest
    case invalidResponse
    case authenticationFailed
    case rateLimited
    case serviceUnavailable
    case responseTooLarge
    case emptyResult
    case networkUnavailable
    case timedOut
}
