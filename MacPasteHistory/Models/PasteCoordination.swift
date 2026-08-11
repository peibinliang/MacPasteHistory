import Foundation

enum PastePayload: Equatable, Sendable {
    case text(String)
    case image(Data)
}

struct PasteRequest: Equatable, Sendable {
    let payload: PastePayload
    let historyID: Int64
}

enum PasteClipboardOnlyReason: Equatable, Sendable {
    case automaticPasteDisabled
    case targetUnavailable
    case commandFailed
}

enum PasteFailure: Equatable, Sendable {
    case clipboardWrite
    case dispatchPreparation
    case usageAccounting
}

enum PasteOutcome: Equatable, Sendable {
    case pasted
    case clipboardOnly(PasteClipboardOnlyReason)
    case permissionRequired
    case cancelled(clipboardAvailable: Bool)
    case failed(PasteFailure)
}

enum PasteOutcomeFeedback: Equatable, Sendable {
    case none
    case manualPaste
    case permissionRequired

    static func feedback(for outcome: PasteOutcome) -> PasteOutcomeFeedback {
        switch outcome {
        case .pasted, .failed, .cancelled(clipboardAvailable: false):
            return .none
        case .clipboardOnly, .cancelled(clipboardAvailable: true):
            return .manualPaste
        case .permissionRequired:
            return .permissionRequired
        }
    }
}
