import Foundation

struct ClipboardImageCandidate: Equatable {
    let pngData: Data
    let width: Int
    let height: Int
    let format: ClipboardImageFormat
}
