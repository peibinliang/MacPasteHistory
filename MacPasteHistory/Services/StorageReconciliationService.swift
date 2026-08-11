import AppKit
import Foundation

struct StorageReconciliationService {
    private static let temporaryFilePrefix = "mph-image-"
    private static let temporaryFileSuffix = ".tmp"
    private static let temporarySafetyWindow: TimeInterval = 24 * 60 * 60

    private let repository: ClipboardHistoryRepository
    private let imagesDirectory: URL
    private let thumbnailsDirectory: URL
    private let temporaryDirectory: URL
    private let fileManager: FileManager
    private let imageStorageService: ImageStorageService
    private let now: () -> Date

    init(
        repository: ClipboardHistoryRepository,
        imagesDirectory: URL,
        thumbnailsDirectory: URL,
        temporaryDirectory: URL,
        fileManager: FileManager = .default,
        imageStorageService: ImageStorageService? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.imagesDirectory = imagesDirectory
        self.thumbnailsDirectory = thumbnailsDirectory
        self.temporaryDirectory = temporaryDirectory
        self.fileManager = fileManager
        self.imageStorageService = imageStorageService ?? ImageStorageService(
            imagesDirectory: imagesDirectory,
            thumbnailsDirectory: thumbnailsDirectory,
            fileManager: fileManager
        )
        self.now = now
    }

    func scan() throws -> StorageReconciliationInventory {
        var scanIssues: [StorageReconciliationIssue] = []
        let originals = regularFiles(in: imagesDirectory, issues: &scanIssues)
        let thumbnails = regularFiles(in: thumbnailsDirectory, issues: &scanIssues)
        let temporaryFiles = temporaryFiles(in: temporaryDirectory, issues: &scanIssues)
        return StorageReconciliationInventory(
            imageRecords: try repository.imageRecordsForReconciliation(),
            managedOriginalFiles: originals,
            managedThumbnailFiles: thumbnails,
            temporaryFiles: temporaryFiles,
            scanIssues: scanIssues
        )
    }

    func makePlan(from inventory: StorageReconciliationInventory) -> StorageReconciliationPlan {
        var issues = inventory.scanIssues
        var actions: [StorageReconciliationAction] = []
        var referencedOriginals = Set<URL>()
        var referencedThumbnails = Set<URL>()
        let referencedPaths = allReferencedPaths(in: inventory.imageRecords)

        for record in inventory.imageRecords {
            planRecord(
                record,
                referencedOriginals: &referencedOriginals,
                referencedThumbnails: &referencedThumbnails,
                issues: &issues,
                actions: &actions
            )
        }

        appendOrphanIssues(
            files: inventory.managedOriginalFiles,
            referenced: referencedOriginals,
            kind: .orphanedManagedOriginal,
            to: &issues
        )
        appendOrphanIssues(
            files: inventory.managedThumbnailFiles,
            referenced: referencedThumbnails,
            kind: .orphanedManagedThumbnail,
            to: &issues
        )
        appendTemporaryActions(inventory.temporaryFiles, referencedPaths: referencedPaths, to: &actions)

        return StorageReconciliationPlan(issues: issues, actions: actions)
    }

    func reconcile() -> StorageReconciliationReport {
        do {
            let plan = makePlan(from: try scan())
            var completed = 0
            var failed = 0
            for action in plan.actions {
                do {
                    if try apply(action) {
                        completed += 1
                    }
                } catch {
                    failed += 1
                }
            }
            return report(for: plan, completed: completed, failed: failed)
        } catch {
            return StorageReconciliationReport(
                issueCounts: [.itemFailure: 1],
                plannedActionCount: 0,
                completedActionCount: 0,
                failedActionCount: 1
            )
        }
    }

    private func apply(_ action: StorageReconciliationAction) throws -> Bool {
        switch action.kind {
        case .regenerateThumbnail:
            return try regenerateThumbnail(for: action)
        case .deleteStaleTemporaryFile:
            return try deleteStaleTemporaryFile(for: action)
        }
    }

    private func regenerateThumbnail(for action: StorageReconciliationAction) throws -> Bool {
        guard let historyID = action.historyID,
              let sourceURL = action.sourceURL,
              let currentRecord = try repository.historyItem(id: historyID),
              let currentOriginalPath = currentRecord.filePath,
              let currentThumbnailPath = currentRecord.thumbnailPath else {
            return false
        }

        let currentOriginal = canonicalURL(URL(fileURLWithPath: currentOriginalPath))
        let currentThumbnail = canonicalURL(URL(fileURLWithPath: currentThumbnailPath))
        guard currentOriginal == canonicalURL(sourceURL),
              currentThumbnail == canonicalURL(action.fileURL),
              isContained(currentOriginal, in: imagesDirectory),
              isContained(currentThumbnail, in: thumbnailsDirectory),
              fileManager.fileExists(atPath: currentOriginal.path),
              NSImage(contentsOf: currentOriginal) != nil,
              fileManager.fileExists(atPath: currentThumbnail.path) == false else {
            return false
        }

        try imageStorageService.regenerateThumbnail(from: currentOriginal, to: currentThumbnail)
        return true
    }

    private func deleteStaleTemporaryFile(for action: StorageReconciliationAction) throws -> Bool {
        let candidate = canonicalURL(action.fileURL)
        guard candidate == action.fileURL,
              isContained(candidate, in: temporaryDirectory),
              isOwnedTemporaryFilename(candidate.lastPathComponent),
              fileManager.fileExists(atPath: candidate.path) else {
            return false
        }

        let values = try candidate.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey]
        )
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let modificationDate = values.contentModificationDate,
              modificationDate < now().addingTimeInterval(-Self.temporarySafetyWindow),
              try isCurrentlyUnreferenced(candidate) else {
            return false
        }

        try fileManager.removeItem(at: candidate)
        return true
    }

    private func isCurrentlyUnreferenced(_ candidate: URL) throws -> Bool {
        let references = allReferencedPaths(in: try repository.imageRecordsForReconciliation())
        return references.contains(candidate) == false
    }

    private func planRecord(
        _ record: ClipboardHistoryItem,
        referencedOriginals: inout Set<URL>,
        referencedThumbnails: inout Set<URL>,
        issues: inout [StorageReconciliationIssue],
        actions: inout [StorageReconciliationAction]
    ) {
        guard let originalURL = record.filePath.map(URL.init(fileURLWithPath:)) else {
            issues.append(issue(.missingOriginal, record: record))
            return
        }
        guard let thumbnailURL = record.thumbnailPath.map(URL.init(fileURLWithPath:)) else {
            issues.append(issue(.missingThumbnail, record: record))
            return
        }

        let canonicalOriginal = canonicalURL(originalURL)
        let canonicalThumbnail = canonicalURL(thumbnailURL)
        let originalIsManaged = isContained(canonicalOriginal, in: imagesDirectory)
        let thumbnailIsManaged = isContained(canonicalThumbnail, in: thumbnailsDirectory)
        if originalIsManaged {
            referencedOriginals.insert(canonicalOriginal)
        }
        if thumbnailIsManaged {
            referencedThumbnails.insert(canonicalThumbnail)
        }
        guard originalIsManaged, thumbnailIsManaged else {
            issues.append(issue(.uncertainOwnership, record: record))
            return
        }

        guard fileManager.fileExists(atPath: canonicalOriginal.path) else {
            issues.append(issue(.missingOriginal, record: record, fileURL: canonicalOriginal))
            return
        }
        guard NSImage(contentsOf: canonicalOriginal) != nil else {
            issues.append(issue(.corruptedOriginal, record: record, fileURL: canonicalOriginal))
            return
        }
        guard fileManager.fileExists(atPath: canonicalThumbnail.path) == false else { return }

        issues.append(issue(.missingThumbnail, record: record, fileURL: canonicalThumbnail))
        actions.append(
            StorageReconciliationAction(
                kind: .regenerateThumbnail,
                historyID: record.id,
                fileURL: canonicalThumbnail,
                sourceURL: canonicalOriginal
            )
        )
    }

    private func regularFiles(
        in directory: URL,
        issues: inout [StorageReconciliationIssue]
    ) -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ).compactMap { url in
                do {
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    if values.isSymbolicLink == true {
                        issues.append(
                            StorageReconciliationIssue(
                                kind: .uncertainOwnership,
                                historyID: nil,
                                fileURL: canonicalURL(url)
                            )
                        )
                        return nil
                    }
                    guard values.isRegularFile == true else { return nil }
                    return canonicalURL(url)
                } catch {
                    issues.append(StorageReconciliationIssue(kind: .itemFailure, historyID: nil, fileURL: nil))
                    return nil
                }
            }
        } catch {
            issues.append(StorageReconciliationIssue(kind: .itemFailure, historyID: nil, fileURL: nil))
            return []
        }
    }

    private func temporaryFiles(
        in directory: URL,
        issues: inout [StorageReconciliationIssue]
    ) -> [StorageReconciliationFile] {
        regularFiles(in: directory, issues: &issues).compactMap { url in
            do {
                let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
                return StorageReconciliationFile(url: url, modificationDate: values.contentModificationDate)
            } catch {
                issues.append(StorageReconciliationIssue(kind: .itemFailure, historyID: nil, fileURL: nil))
                return nil
            }
        }
    }

    private func appendOrphanIssues(
        files: [URL],
        referenced: Set<URL>,
        kind: StorageReconciliationIssueKind,
        to issues: inout [StorageReconciliationIssue]
    ) {
        for file in files where referenced.contains(file) == false {
            issues.append(StorageReconciliationIssue(kind: kind, historyID: nil, fileURL: file))
        }
    }

    private func appendTemporaryActions(
        _ files: [StorageReconciliationFile],
        referencedPaths: Set<URL>,
        to actions: inout [StorageReconciliationAction]
    ) {
        let cutoff = now().addingTimeInterval(-Self.temporarySafetyWindow)
        for file in files {
            let name = file.url.lastPathComponent
            guard isContained(file.url, in: temporaryDirectory),
                  isOwnedTemporaryFilename(name),
                  referencedPaths.contains(file.url) == false,
                  let modificationDate = file.modificationDate,
                  modificationDate < cutoff else {
                continue
            }
            actions.append(
                StorageReconciliationAction(
                    kind: .deleteStaleTemporaryFile,
                    historyID: nil,
                    fileURL: file.url,
                    sourceURL: nil
                )
            )
        }
    }

    private func isOwnedTemporaryFilename(_ name: String) -> Bool {
        name.hasPrefix(Self.temporaryFilePrefix) && name.hasSuffix(Self.temporaryFileSuffix)
    }

    private func allReferencedPaths(in records: [ClipboardHistoryItem]) -> Set<URL> {
        Set(records.flatMap { record in
            [record.filePath, record.thumbnailPath].compactMap { path in
                path.map { canonicalURL(URL(fileURLWithPath: $0)) }
            }
        })
    }

    private func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func isContained(_ candidate: URL, in root: URL) -> Bool {
        let canonicalRoot = canonicalURL(root)
        return candidate.path.hasPrefix(canonicalRoot.path + "/")
    }

    private func issue(
        _ kind: StorageReconciliationIssueKind,
        record: ClipboardHistoryItem,
        fileURL: URL? = nil
    ) -> StorageReconciliationIssue {
        StorageReconciliationIssue(kind: kind, historyID: record.id, fileURL: fileURL)
    }

    private func report(
        for plan: StorageReconciliationPlan,
        completed: Int,
        failed: Int
    ) -> StorageReconciliationReport {
        let counts = Dictionary(grouping: plan.issues, by: \.kind).mapValues(\.count)
        return StorageReconciliationReport(
            issueCounts: counts,
            plannedActionCount: plan.actions.count,
            completedActionCount: completed,
            failedActionCount: failed
        )
    }
}
