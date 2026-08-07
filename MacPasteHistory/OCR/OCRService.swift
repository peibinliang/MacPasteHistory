import AppKit
import Foundation
import Vision

final class OCRService: OCRServicing, @unchecked Sendable {
    private let executor: any OCRRequestExecuting

    init(executor: any OCRRequestExecuting = VisionOCRRequestExecutor()) {
        self.executor = executor
    }

    func recognizeText(in imageURL: URL) async throws -> OCRResult {
        let observations = try await executor.recognizeObservations(in: imageURL)
            .filter { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .sorted(by: OCRService.isOrderedBefore)
        guard observations.isEmpty == false else { throw OCRServiceError.noTextFound }
        return OCRResult(
            text: observations.map(\.text).joined(separator: "\n"),
            observationsCount: observations.count,
            languages: Array(Set(observations.compactMap(\.language))).sorted()
        )
    }

    static func isOrderedBefore(_ lhs: OCRTextObservation, _ rhs: OCRTextObservation) -> Bool {
        let verticalDelta = lhs.boundingBox.midY - rhs.boundingBox.midY
        if abs(verticalDelta) > 0.02 { return verticalDelta > 0 }
        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }
}

private final class VisionOCRRequestExecutor: OCRRequestExecuting, @unchecked Sendable {
    func recognizeObservations(in imageURL: URL) async throws -> [OCRTextObservation] {
        let task = Task<[OCRTextObservation], Error>.detached(priority: .userInitiated) { () throws -> [OCRTextObservation] in
            guard FileManager.default.fileExists(atPath: imageURL.path) else {
                throw OCRServiceError.imageMissing
            }
            guard let image = NSImage(contentsOf: imageURL),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw OCRServiceError.imageDecodeFailed
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            do {
                try VNImageRequestHandler(cgImage: cgImage).perform([request])
            } catch {
                throw OCRServiceError.visionFailed
            }
            return (request.results ?? []).map { observation in
                let candidate = observation.topCandidates(1).first
                return OCRTextObservation(
                    text: candidate?.string ?? "",
                    boundingBox: observation.boundingBox,
                    language: candidate == nil ? nil : request.recognitionLanguages.first
                )
            }
        }
        return try await task.value
    }
}
