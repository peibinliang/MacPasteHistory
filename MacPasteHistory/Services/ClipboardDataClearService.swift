import Foundation

protocol AITokenUsageDeleting {
    func deleteAll() throws
}

extension AITokenUsageRepository: AITokenUsageDeleting {}

struct ClipboardDataClearService {
    private let repository: ClipboardHistoryRepository
    private let imageStorageService: ImageStorageService
    private let aiTokenUsageRepository: (any AITokenUsageDeleting)?

    init(
        repository: ClipboardHistoryRepository,
        imageStorageService: ImageStorageService,
        aiTokenUsageRepository: (any AITokenUsageDeleting)? = nil
    ) {
        self.repository = repository
        self.imageStorageService = imageStorageService
        self.aiTokenUsageRepository = aiTokenUsageRepository
    }

    func clearAllData() throws {
        var firstError: (any Error)?
        var didDeleteAITokenUsage = false

        do {
            try repository.clearAllHistory()
        } catch {
            firstError = error
        }
        do {
            if let aiTokenUsageRepository {
                try aiTokenUsageRepository.deleteAll()
                didDeleteAITokenUsage = true
            }
        } catch {
            firstError = firstError ?? error
        }
        do {
            try imageStorageService.deleteAllFiles()
        } catch {
            firstError = firstError ?? error
        }

        if didDeleteAITokenUsage {
            NotificationCenter.default.post(name: .aiTokenUsageDidChange, object: nil)
        }

        if let firstError {
            throw firstError
        }
    }
}
