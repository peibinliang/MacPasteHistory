import Foundation

/// Performs periodic data cleanup for clipboard history records.
/// Removes expired records, trims count limits, and evicts image files when storage caps are exceeded.
struct DataCleanupService {
    private let repository: ClipboardHistoryRepository
    private let imageStorageService: ImageStorageService?
    private let settings: UserDefaultsConfig
    private let logger: Logger

    init(
        repository: ClipboardHistoryRepository,
        imageStorageService: ImageStorageService? = nil,
        settings: UserDefaultsConfig = UserDefaultsConfig(),
        logger: Logger = Logger(category: "DataCleanup")
    ) {
        self.repository = repository
        self.imageStorageService = imageStorageService
        self.settings = settings
        self.logger = logger
    }

    /// Called on app startup. Removes expired records and prunes oldest records beyond configured limits.
    func performStartupCleanup() {
        do {
            try cleanupExpiredRecords()
        } catch {
            logger.error("Failed to clean expired records: \(error.localizedDescription)")
        }

        do {
            try trimTextHistoryToLimit()
        } catch {
            logger.error("Failed to trim text history: \(error.localizedDescription)")
        }

        do {
            try trimImageHistoryToLimit()
        } catch {
            logger.error("Failed to trim image history: \(error.localizedDescription)")
        }

        do {
            try evictImageFilesBeyondStorageLimit()
        } catch {
            logger.error("Failed to evict image files: \(error.localizedDescription)")
        }
    }

    // MARK: - Private cleanup steps

    private func cleanupExpiredRecords() throws {
        let retentionDays = settings.historyRetentionDays
        let expiredImageRecords = try repository.expiredImageRecords(retentionDays: retentionDays)
        for item in expiredImageRecords {
            imageStorageService?.deleteImageFiles(for: item)
        }
        let before = try repository.textRecordCount()
        try repository.deleteExpiredRecords(retentionDays: retentionDays)
        let removed = before - (try repository.textRecordCount())
        logger.info("Expired cleanup removed \(removed) records (retention: \(retentionDays) days)")
    }

    private func trimTextHistoryToLimit() throws {
        let maxCount = settings.maxTextHistoryCount
        let excessIDs = try repository.textRecordsExceeding(limit: maxCount)
        guard !excessIDs.isEmpty else { return }

        for id in excessIDs {
            try repository.deleteItem(id: id)
        }
        logger.info("Trimmed \(excessIDs.count) text records beyond limit of \(maxCount)")
    }

    private func trimImageHistoryToLimit() throws {
        let maxCount = settings.maxImageHistoryCount
        let recordsToTrim = try repository.imageRecordsForEviction(limit: maxCount)
        guard !recordsToTrim.isEmpty else { return }

        for item in recordsToTrim {
            imageStorageService?.deleteImageFiles(for: item)
            try repository.deleteItem(id: item.id)
        }
        logger.info("Trimmed \(recordsToTrim.count) image records beyond limit of \(maxCount)")
    }

    private func evictImageFilesBeyondStorageLimit() throws {
        let maxStorage = settings.totalStorageCapInBytes
        let recordsToEvict = try repository.imageRecordsBeyondStorage(maxStorageInBytes: maxStorage)
        guard !recordsToEvict.isEmpty else { return }

        for item in recordsToEvict {
            imageStorageService?.deleteImageFiles(for: item)
            try repository.deleteItem(id: item.id)
        }
        logger.info("Evicted \(recordsToEvict.count) image records beyond storage limit of \(maxStorage) bytes")
    }
}
