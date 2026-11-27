import Foundation

struct ClipboardImageCandidate: Equatable, Sendable {
    let pngData: Data
    let width: Int
    let height: Int
    let format: ClipboardImageFormat
}
