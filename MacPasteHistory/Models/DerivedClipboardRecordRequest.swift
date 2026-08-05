import Foundation

struct DerivedClipboardRecordRequest {
    let text: String
    let sourceHistoryID: Int64
    let actionID: String
    let actionSummary: String
    let sourcePreview: String
    let sourceHash: String
    let detection: ContentDetectionResult
}
