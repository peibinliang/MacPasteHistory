import Foundation

struct ContentDetectionResult: Equatable {
    let type: DetectedContentType
    let confidence: Double
    let version: Int
    let detectedAt: Date

    init(type: DetectedContentType, confidence: Double, version: Int, detectedAt: Date) {
        self.type = type
        self.confidence = min(max(confidence, 0), 1)
        self.version = version
        self.detectedAt = detectedAt
    }
}
