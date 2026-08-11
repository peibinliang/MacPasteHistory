import Foundation

/// Immutable metadata captured once for a single pasteboard change.
struct ClipboardCaptureContext {
    let sourceApplication: SourceApplication
    let capturedAt: Date
}
