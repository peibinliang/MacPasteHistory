import XCTest
@testable import MacPasteHistory

final class AITextPolishingTests: XCTestCase {
    func testService_withoutCredential_shouldFailBeforeCallingClient() async {
        let client = PolishingClientFake()
        let service = AITextPolishingService(
            credentialStore: PolishingCredentialFake(apiKey: nil),
            client: client
        )

        do {
            _ = try await service.polish("draft")
            XCTFail("Expected missing credential failure")
        } catch let error as ContentActionError {
            XCTAssertEqual(error.messageKey, "ai.error.missing-api-key")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(client.callCount, 0)
    }

    func testService_shouldPersistProviderUsageExactlyOnce() async throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let repository = AITokenUsageRepository(database: temporary.connection)
        let response = DeepSeekPolishingResult(
            requestID: "same-response",
            modelIdentifier: "deepseek-v4-flash",
            polishedText: "Polished",
            usage: DeepSeekTokenUsage(inputTokens: 8, outputTokens: 3, totalTokens: 11, cachedInputTokens: 2)
        )
        let client = PolishingClientFake(result: .success(response))
        let service = AITextPolishingService(
            credentialStore: PolishingCredentialFake(apiKey: "synthetic-key"),
            client: client,
            usageRepository: repository
        )

        _ = try await service.polish("draft")
        _ = try await service.polish("draft")

        XCTAssertEqual(try repository.summary().requestCount, 1)
        XCTAssertEqual(try repository.summary().totalTokens, 11)
    }

    func testAction_whenProviderOmitsUsage_shouldKeepUsableOutputAndUnavailableState() async throws {
        let service = PolishingServiceFake(outcomes: [
            .success(AITextPolishingOutcome(text: "Better", usage: nil, usagePersistenceFailed: false))
        ])
        let action = AITextPolishingAction(service: service)

        let result = try await action.executeAsync(input: "Draft")

        XCTAssertEqual(result.output, "Better")
        XCTAssertNil(result.aiTokenUsage)
        XCTAssertTrue(result.isAIUsageUnavailable)
        XCTAssertFalse(action.supportedTypes.contains(.image))
    }

    func testService_whenRequestFails_shouldNotInsertUsage() async throws {
        let temporary = try TemporaryDatabase()
        defer { temporary.remove() }
        try MigrationManager(database: temporary.connection).migrate()
        let repository = AITokenUsageRepository(database: temporary.connection)
        let service = AITextPolishingService(
            credentialStore: PolishingCredentialFake(apiKey: "synthetic-key"),
            client: PolishingClientFake(result: .failure(DeepSeekClientError.rateLimited)),
            usageRepository: repository
        )

        do {
            _ = try await service.polish("draft")
            XCTFail("Expected rate-limit failure")
        } catch let error as ContentActionError {
            XCTAssertEqual(error.messageKey, "ai.error.rate-limited")
        }
        XCTAssertEqual(try repository.summary(), .zero)
    }
}

@MainActor
final class AITextPolishingViewModelTests: XCTestCase {
    func testPolishingIsAvailableForPlainTextButNotRecommendedForURL() {
        let defaults = isolatedDefaults()
        defer { defaults.defaults.removePersistentDomain(forName: defaults.name) }
        let service = PolishingServiceFake(outcomes: [])
        let viewModel = makeViewModel(service: service, config: UserDefaultsConfig(defaults: defaults.defaults))

        viewModel.present(for: makeItem())

        XCTAssertTrue(viewModel.availableActions.contains { $0.id == AITextPolishingAction.actionID })
        XCTAssertFalse(viewModel.recommendedActions(for: .url).contains { $0.id == AITextPolishingAction.actionID })
    }

    func testFirstUseDecline_shouldSendNoRequestAndKeepChoosingState() {
        let defaults = isolatedDefaults()
        defer { defaults.defaults.removePersistentDomain(forName: defaults.name) }
        let service = PolishingServiceFake(outcomes: [])
        let viewModel = makeViewModel(service: service, config: UserDefaultsConfig(defaults: defaults.defaults))
        viewModel.present(for: makeItem())

        viewModel.execute(actionID: AITextPolishingAction.actionID)
        XCTAssertTrue(viewModel.isAIRemoteProcessingConsentRequired)

        viewModel.declineAIRemoteProcessing()

        XCTAssertEqual(service.callCount, 0)
        XCTAssertEqual(viewModel.state, .choosing)
    }

    func testAcceptedPolishing_shouldPublishEditablePreviewAndUsage() async {
        let defaults = isolatedDefaults()
        defer { defaults.defaults.removePersistentDomain(forName: defaults.name) }
        var config = UserDefaultsConfig(defaults: defaults.defaults)
        config.hasAcknowledgedAIRemoteProcessing = true
        let usage = DeepSeekTokenUsage(inputTokens: 4, outputTokens: 2, totalTokens: 6, cachedInputTokens: nil)
        let service = PolishingServiceFake(outcomes: [
            .success(AITextPolishingOutcome(text: "Polished", usage: usage, usagePersistenceFailed: false))
        ])
        let viewModel = makeViewModel(service: service, config: config)
        viewModel.present(for: makeItem())

        viewModel.execute(actionID: AITextPolishingAction.actionID)
        await waitUntil { viewModel.state == .previewing }
        viewModel.updateEditedOutput("Edited")

        XCTAssertEqual(viewModel.editedOutput, "Edited")
        XCTAssertEqual(viewModel.aiTokenUsage, usage)
    }

    func testFirstUseAcceptance_shouldPersistDisclosureAndStartRequest() async {
        let defaults = isolatedDefaults()
        defer { defaults.defaults.removePersistentDomain(forName: defaults.name) }
        let config = UserDefaultsConfig(defaults: defaults.defaults)
        let service = PolishingServiceFake(outcomes: [
            .success(AITextPolishingOutcome(text: "Accepted", usage: nil, usagePersistenceFailed: false))
        ])
        let viewModel = makeViewModel(service: service, config: config)
        viewModel.present(for: makeItem())

        viewModel.execute(actionID: AITextPolishingAction.actionID)
        viewModel.acceptAIRemoteProcessing()
        await waitUntil { viewModel.state == .previewing }

        XCTAssertTrue(config.hasAcknowledgedAIRemoteProcessing)
        XCTAssertEqual(service.callCount, 1)
        XCTAssertEqual(viewModel.editedOutput, "Accepted")
    }

    func testSupersededRequest_shouldIgnoreLateResult() async {
        let defaults = isolatedDefaults()
        defer { defaults.defaults.removePersistentDomain(forName: defaults.name) }
        var config = UserDefaultsConfig(defaults: defaults.defaults)
        config.hasAcknowledgedAIRemoteProcessing = true
        let service = PolishingServiceFake(outcomes: [
            .success(AITextPolishingOutcome(text: "Late", usage: nil, usagePersistenceFailed: false)),
            .success(AITextPolishingOutcome(text: "Latest", usage: nil, usagePersistenceFailed: false))
        ], delays: [.milliseconds(80), .milliseconds(1)])
        let viewModel = makeViewModel(service: service, config: config)
        viewModel.present(for: makeItem())

        viewModel.execute(actionID: AITextPolishingAction.actionID)
        viewModel.execute(actionID: AITextPolishingAction.actionID)
        await waitUntil { viewModel.state == .previewing }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.editedOutput, "Latest")
    }

    private func makeViewModel(service: PolishingServiceFake, config: UserDefaultsConfig) -> ContentActionPanelViewModel {
        let registry = ContentActionRegistry(actions: [AITextPolishingAction(service: service)])
        return ContentActionPanelViewModel(registry: registry, config: config)
    }

    private func makeItem() -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: 1, contentType: .text, textContent: "Draft", filePath: nil, thumbnailPath: nil,
            sourceApp: nil, sourceBundleID: nil, contentHash: "hash", textLength: 5, fileSize: nil,
            imageWidth: nil, imageHeight: nil, imageFormat: nil, isFavorite: false, isSensitive: false,
            createdAt: .distantPast, updatedAt: .distantPast
        )
    }

    private func isolatedDefaults() -> (defaults: UserDefaults, name: String) {
        let name = "AITextPolishingViewModelTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name) ?? .standard, name)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 where condition() == false {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

private final class PolishingCredentialFake: AICredentialStoring, @unchecked Sendable {
    private let apiKey: String?
    init(apiKey: String?) { self.apiKey = apiKey }
    func readAPIKey() throws -> String? { apiKey }
    func hasAPIKey() throws -> Bool { apiKey != nil }
    func saveAPIKey(_ apiKey: String) throws {}
    func deleteAPIKey() throws {}
}

private final class PolishingClientFake: DeepSeekClientProtocol, @unchecked Sendable {
    private let result: Result<DeepSeekPolishingResult, Error>
    private(set) var callCount = 0
    init(result: Result<DeepSeekPolishingResult, Error> = .failure(DeepSeekClientError.serviceUnavailable)) {
        self.result = result
    }
    func polish(text: String, modelIdentifier: String, apiKey: String) async throws -> DeepSeekPolishingResult {
        callCount += 1
        return try result.get()
    }
}

private final class PolishingServiceFake: AITextPolishingServing, @unchecked Sendable {
    private var outcomes: [Result<AITextPolishingOutcome, Error>]
    private var delays: [Duration]
    private(set) var callCount = 0

    init(outcomes: [Result<AITextPolishingOutcome, Error>], delays: [Duration] = []) {
        self.outcomes = outcomes
        self.delays = delays
    }

    func polish(_ text: String) async throws -> AITextPolishingOutcome {
        let index = callCount
        callCount += 1
        if delays.indices.contains(index) {
            try? await Task.sleep(for: delays[index])
        }
        guard outcomes.indices.contains(index) else {
            throw DeepSeekClientError.serviceUnavailable
        }
        return try outcomes[index].get()
    }
}
