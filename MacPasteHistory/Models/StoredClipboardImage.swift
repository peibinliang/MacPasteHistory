import Foundation

struct StoredClipboardImage: Equatable {
    let fileURL: URL
    let thumbnailURL: URL
    let contentHash: String
    let fileSize: Int
    let width: Int
    let height: Int
    let format: ClipboardImageFormat
}
