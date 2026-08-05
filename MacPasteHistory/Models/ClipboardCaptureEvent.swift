import Foundation

struct ClipboardCaptureEvent: Identifiable, Equatable {
    let id: Int64
    let historyID: Int64
    let sourceApp: String?
    let sourceBundleID: String?
    let capturedAt: Date
}
