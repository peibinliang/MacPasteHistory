import Foundation

struct ClipboardCaptureEventSummary: Identifiable, Equatable {
    let id: Int64
    let historyID: Int64
    let sourceApp: String?
    let sourceBundleID: String?
    let captureCount: Int
    let firstCapturedAt: Date
    let lastCapturedAt: Date
}
