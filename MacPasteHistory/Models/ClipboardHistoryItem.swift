import Foundation

struct ClipboardHistoryItem: Identifiable, Equatable {
    let id: Int64
    let contentType: ClipboardContentType
    let textContent: String
    let filePath: String?
    let thumbnailPath: String?
    let sourceApp: String?
    let sourceBundleID: String?
    let contentHash: String
    let textLength: Int
    let fileSize: Int?
    let imageWidth: Int?
    let imageHeight: Int?
    let imageFormat: ClipboardImageFormat?
    let isFavorite: Bool
    let isSensitive: Bool
    let createdAt: Date
    let updatedAt: Date
}
