import Foundation

actor ContentClassificationService {
    private let repository: ClipboardHistoryRepository
    private let classifier: ContentClassifier

    init(repository: ClipboardHistoryRepository, classifier: ContentClassifier = ContentClassifier()) {
        self.repository = repository
        self.classifier = classifier
    }

    func classifyIfNeeded(item: ClipboardHistoryItem) async {
        guard item.contentType == .text,
              item.userOverrideType == nil,
              item.detectionVersion != ContentClassifier.currentVersion else { return }
        let result = classifier.classifyComplete(item.textContent)
        try? repository.updateDetectedType(id: item.id, result: result)
    }

    func effectiveType(for item: ClipboardHistoryItem) async -> DetectedContentType {
        if item.userOverrideType != nil { return item.effectiveDetectedType }
        await classifyIfNeeded(item: item)
        return (try? repository.historyItem(id: item.id))?.effectiveDetectedType ?? item.effectiveDetectedType
    }
}
