import Foundation

struct OCRResult: Equatable {
    let text: String
    let observationsCount: Int
    let languages: [String]
}

struct OCRTextObservation: Equatable, Sendable {
    let text: String
    let boundingBox: CGRect
    let language: String?
}

enum OCRServiceError: String, Error, Equatable {
    case imageMissing
    case imageDecodeFailed
    case visionFailed
    case noTextFound
}

protocol OCRServicing: Sendable {
    func recognizeText(in imageURL: URL) async throws -> OCRResult
}

protocol OCRRequestExecuting: Sendable {
    func recognizeObservations(in imageURL: URL) async throws -> [OCRTextObservation]
}
