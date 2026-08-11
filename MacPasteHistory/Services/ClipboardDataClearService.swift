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

        do {
            try repository.clearAllHistory()
        } catch {
            firstError = error
        }
        do {
            try aiTokenUsageRepository?.deleteAll()
        } catch {
            firstError = firstError ?? error
        }
        do {
            try imageStorageService.deleteAllFiles()
        } catch {
            firstError = firstError ?? error
        }

        if let firstError {
            throw firstError
        }
    }
}
