import Foundation

enum StorageReconciliationIssueKind: String, Hashable, Sendable {
    case missingOriginal
    case orphanedManagedOriginal
    case orphanedManagedThumbnail
    case missingThumbnail
    case corruptedOriginal
    case uncertainOwnership
    case itemFailure
}

struct StorageReconciliationIssue: Equatable, Sendable {
    let kind: StorageReconciliationIssueKind
    let historyID: Int64?
    let fileURL: URL?
}

enum StorageReconciliationActionKind: String, Hashable, Sendable {
    case regenerateThumbnail
    case deleteStaleTemporaryFile
}

struct StorageReconciliationAction: Equatable, Sendable {
    let kind: StorageReconciliationActionKind
    let historyID: Int64?
    let fileURL: URL
    let sourceURL: URL?
}

struct StorageReconciliationPlan: Equatable, Sendable {
    let issues: [StorageReconciliationIssue]
    let actions: [StorageReconciliationAction]
}

struct StorageReconciliationReport: Equatable, Sendable {
    let issueCounts: [StorageReconciliationIssueKind: Int]
    let plannedActionCount: Int
    let completedActionCount: Int
    let failedActionCount: Int
}

struct StorageReconciliationInventory {
    let imageRecords: [ClipboardHistoryItem]
    let managedOriginalFiles: [URL]
    let managedThumbnailFiles: [URL]
    let temporaryFiles: [StorageReconciliationFile]
    let scanIssues: [StorageReconciliationIssue]
}

struct StorageReconciliationFile {
    let url: URL
    let modificationDate: Date?
}
