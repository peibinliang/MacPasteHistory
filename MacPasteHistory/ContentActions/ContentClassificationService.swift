import Foundation

actor ContentClassificationService {
    private let databaseURL: URL
    private let classifier: ContentClassifier

    init(databaseURL: URL, classifier: ContentClassifier = ContentClassifier()) {
        self.databaseURL = databaseURL
        self.classifier = classifier
    }

    func classifyIfNeeded(item: ClipboardHistoryItem) async {
        guard item.contentType == .text,
              item.userOverrideType == nil,
              item.detectionVersion != ContentClassifier.currentVersion else { return }
        let result = classifier.classifyComplete(item.textContent)
        let repository = try? makeRepository()
        try? repository?.updateDetectedType(id: item.id, result: result)
    }

    func effectiveType(for item: ClipboardHistoryItem) async -> DetectedContentType {
        if item.userOverrideType != nil { return item.effectiveDetectedType }
        await classifyIfNeeded(item: item)
        let repository = try? makeRepository()
        return (try? repository?.historyItem(id: item.id))?.effectiveDetectedType ?? item.effectiveDetectedType
    }

    private func makeRepository() throws -> ClipboardHistoryRepository {
        ClipboardHistoryRepository(database: try DatabaseConnection(databaseURL: databaseURL, mode: .readWriteCreate))
    }
}
