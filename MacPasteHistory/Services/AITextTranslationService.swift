import Foundation

struct AITextTranslationOutcome: Equatable, Sendable {
    let text: String
    let usage: DeepSeekTokenUsage?
    let usagePersistenceFailed: Bool
}

protocol AITextTranslationServing: Sendable {
    func translate(_ text: String) async throws -> AITextTranslationOutcome
}

final class AITextTranslationService: AITextTranslationServing, @unchecked Sendable {
    private let config: UserDefaultsConfig
    private let credentialStore: any AICredentialStoring
    private let client: any DeepSeekClientProtocol
    private let usageRepository: AITokenUsageRepository?

    init(
        config: UserDefaultsConfig = UserDefaultsConfig(),
        credentialStore: any AICredentialStoring = LocalFileAICredentialStore(),
        client: any DeepSeekClientProtocol = DeepSeekClient(),
        usageRepository: AITokenUsageRepository? = nil
    ) {
        self.config = config
        self.credentialStore = credentialStore
        self.client = client
        self.usageRepository = usageRepository
    }

    func translate(_ text: String) async throws -> AITextTranslationOutcome {
        guard let apiKey = try credentialStore.readAPIKey() else {
            throw ContentActionError.invalidInput(messageKey: "ai.error.missing-api-key")
        }
        let requestedModel = config.aiModelIdentifier
        let response: DeepSeekPolishingResult
        do {
            response = try await client.translate(
                text: text,
                target: config.aiTranslationTarget,
                modelIdentifier: requestedModel,
                apiKey: apiKey
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DeepSeekClientError {
            throw AIServiceErrorMapper.map(error)
        }

        let persistenceFailed = persistUsage(response, requestedModel: requestedModel) == false
        return AITextTranslationOutcome(
            text: response.polishedText,
            usage: response.usage,
            usagePersistenceFailed: persistenceFailed
        )
    }

    private func persistUsage(_ response: DeepSeekPolishingResult, requestedModel: String) -> Bool {
        guard let usage = response.usage, let usageRepository else { return true }
        do {
            let didInsert = try usageRepository.insert(AITokenUsageRecord(
                requestID: response.requestID,
                provider: AITextPolishingService.providerIdentifier,
                modelIdentifier: requestedModel,
                inputTokens: usage.inputTokens,
                outputTokens: usage.outputTokens,
                totalTokens: usage.totalTokens,
                cachedInputTokens: usage.cachedInputTokens,
                createdAt: Date()
            ))
            if didInsert { NotificationCenter.default.post(name: .aiTokenUsageDidChange, object: nil) }
            return true
        } catch {
            return false
        }
    }
}

enum AIServiceErrorMapper {
    static func map(_ error: DeepSeekClientError) -> ContentActionError {
        switch error {
        case .authenticationFailed: .parseFailed(messageKey: "ai.error.authentication")
        case .rateLimited: .parseFailed(messageKey: "ai.error.rate-limited")
        case .networkUnavailable: .parseFailed(messageKey: "ai.error.offline")
        case .timedOut: .parseFailed(messageKey: "ai.error.timeout")
        case .responseTooLarge: .parseFailed(messageKey: "ai.error.response-too-large")
        case .emptyResult: .emptyResult(messageKey: "ai.error.empty-result")
        case .invalidInput: .invalidInput(messageKey: "ai.error.invalid-input")
        case .invalidRequest, .invalidResponse, .serviceUnavailable:
            .parseFailed(messageKey: "ai.error.service-unavailable")
        }
    }
}
