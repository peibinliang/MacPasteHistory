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
