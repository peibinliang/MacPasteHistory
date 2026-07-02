import Foundation

struct ClipboardDataClearService {
    private let repository: ClipboardHistoryRepository
    private let imageStorageService: ImageStorageService

    init(repository: ClipboardHistoryRepository, imageStorageService: ImageStorageService) {
        self.repository = repository
        self.imageStorageService = imageStorageService
    }

    func clearAllData() throws {
        try repository.clearAllHistory()
        try imageStorageService.deleteAllFiles()
    }
}
