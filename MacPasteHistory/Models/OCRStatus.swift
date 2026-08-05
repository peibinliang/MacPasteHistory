import Foundation

enum OCRStatus: String, Codable {
    case notStarted
    case recognizing
    case recognized
    case failed
}
