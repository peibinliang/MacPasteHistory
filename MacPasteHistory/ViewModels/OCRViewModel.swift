import Combine
import Foundation

enum OCRViewState: Equatable {
    case idle
    case recognizing
    case editing
    case failed(OCRServiceError)
}

protocol OCRResultPersisting: AnyObject {
    func saveOCRResult(id: Int64, text: String, detection: ContentDetectionResult) throws
    func markOCRFailure(id: Int64, errorCode: String, at date: Date) throws
}

extension ClipboardHistoryRepository: OCRResultPersisting {}

@MainActor
final class OCRViewModel: ObservableObject {
    @Published private(set) var state: OCRViewState = .idle
    @Published var editableText: String = ""

    private let service: any OCRServicing
    private let repository: any OCRResultPersisting
    private let classifier: ContentClassifier
    private let didSave: () -> Void
    private var activeRequestID: UUID?

    init(
        service: any OCRServicing = OCRService(),
        repository: any OCRResultPersisting,
        classifier: ContentClassifier = ContentClassifier(),
        didSave: @escaping () -> Void = {}
    ) {
        self.service = service
        self.repository = repository
        self.classifier = classifier
        self.didSave = didSave
    }

    func recognize(item: ClipboardHistoryItem) async {
        guard item.contentType == .image, state != .recognizing,
              let imagePath = item.filePath else { return }
        editableText = item.ocrText ?? editableText
        let requestID = UUID()
        activeRequestID = requestID
        state = .recognizing
        do {
            let result = try await service.recognizeText(in: URL(fileURLWithPath: imagePath))
            guard activeRequestID == requestID else { return }
            editableText = result.text
            state = .editing
        } catch let error as OCRServiceError {
            guard activeRequestID == requestID else { return }
            try? repository.markOCRFailure(id: item.id, errorCode: error.rawValue, at: Date())
            state = .failed(error)
        } catch {
            guard activeRequestID == requestID else { return }
            try? repository.markOCRFailure(id: item.id, errorCode: OCRServiceError.visionFailed.rawValue, at: Date())
            state = .failed(.visionFailed)
        }
        activeRequestID = nil
    }

    func save(item: ClipboardHistoryItem) async {
        guard item.contentType == .image, state == .editing else { return }
        do {
            try repository.saveOCRResult(
                id: item.id,
                text: editableText,
                detection: classifier.classifyComplete(editableText)
            )
            state = .idle
            didSave()
        } catch {
            state = .failed(.visionFailed)
        }
    }

    func cancel() {
        activeRequestID = nil
        state = .idle
    }

    func retry(item: ClipboardHistoryItem) async {
        await recognize(item: item)
    }
}
