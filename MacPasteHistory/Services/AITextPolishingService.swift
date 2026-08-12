import Foundation

struct AITextPolishingOutcome: Equatable, Sendable {
    let text: String
    let usage: DeepSeekTokenUsage?
    let usagePersistenceFailed: Bool
}

protocol AITextPolishingServing: Sendable {
    func polish(_ text: String) async throws -> AITextPolishingOutcome
}

final class AITextPolishingService: AITextPolishingServing, @unchecked Sendable {
    static let providerIdentifier = "deepseek"

    private let config: UserDefaultsConfig
    private let credentialStore: any AICredentialStoring
    private let client: any DeepSeekClientProtocol
    private let usageRepository: AITokenUsageRepository?

    init(
        config: UserDefaultsConfig = UserDefaultsConfig(),
        credentialStore: any AICredentialStoring = KeychainAICredentialStore(),
        client: any DeepSeekClientProtocol = DeepSeekClient(),
        usageRepository: AITokenUsageRepository? = nil
    ) {
        self.config = config
        self.credentialStore = credentialStore
        self.client = client
        self.usageRepository = usageRepository
    }

    func polish(_ text: String) async throws -> AITextPolishingOutcome {
        guard let apiKey = try credentialStore.readAPIKey() else {
            throw ContentActionError.invalidInput(messageKey: "ai.error.missing-api-key")
        }
        let requestedModelIdentifier = config.aiModelIdentifier
        let response: DeepSeekPolishingResult
        do {
            response = try await client.polish(
                text: text,
                modelIdentifier: requestedModelIdentifier,
                apiKey: apiKey
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DeepSeekClientError {
            throw map(error)
        }

        var persistenceFailed = false
        if let usage = response.usage, let usageRepository {
            do {
                let didInsert = try usageRepository.insert(AITokenUsageRecord(
                    requestID: response.requestID,
                    provider: Self.providerIdentifier,
                    modelIdentifier: requestedModelIdentifier,
                    inputTokens: usage.inputTokens,
                    outputTokens: usage.outputTokens,
                    totalTokens: usage.totalTokens,
                    cachedInputTokens: usage.cachedInputTokens,
                    createdAt: Date()
                ))
                if didInsert {
                    NotificationCenter.default.post(name: .aiTokenUsageDidChange, object: nil)
                }
            } catch {
                persistenceFailed = true
            }
        }
        return AITextPolishingOutcome(
            text: response.polishedText,
            usage: response.usage,
            usagePersistenceFailed: persistenceFailed
        )
    }

    private func map(_ error: DeepSeekClientError) -> ContentActionError {
        switch error {
        case .authenticationFailed:
            .parseFailed(messageKey: "ai.error.authentication")
        case .rateLimited:
            .parseFailed(messageKey: "ai.error.rate-limited")
        case .networkUnavailable:
            .parseFailed(messageKey: "ai.error.offline")
        case .timedOut:
            .parseFailed(messageKey: "ai.error.timeout")
        case .responseTooLarge:
            .parseFailed(messageKey: "ai.error.response-too-large")
        case .emptyResult:
            .emptyResult(messageKey: "ai.error.empty-result")
        case .invalidInput:
            .invalidInput(messageKey: "ai.error.invalid-input")
        case .invalidRequest, .invalidResponse, .serviceUnavailable:
            .parseFailed(messageKey: "ai.error.service-unavailable")
        }
    }
}
