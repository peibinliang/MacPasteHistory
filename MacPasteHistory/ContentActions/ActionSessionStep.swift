import Foundation

struct ActionSessionStep: Identifiable, Equatable {
    let id: UUID
    let actionID: ContentActionID
    let actionTitleKey: String
    let input: String
    let originalResult: ContentActionResult
    var editedOutput: String
    let error: ContentActionError?
}
