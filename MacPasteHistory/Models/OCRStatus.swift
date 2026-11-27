import Foundation

enum OCRStatus: String, Codable, Sendable {
    case notStarted
    case recognizing
    case recognized
    case failed
}
