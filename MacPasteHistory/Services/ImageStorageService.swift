import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageStorageError: Error {
    case invalidImageData
    case imageTooLarge
    case thumbnailEncodingFailed
}

final class ImageStorageService: @unchecked Sendable {
    private let imagesDirectory: URL
    private let thumbnailsDirectory: URL
    private let maxImageSizeInBytesProvider: () -> Int
    private let fileManager: FileManager
    private let thumbnailMaxDimension: CGFloat

    init(
        imagesDirectory: URL,
        thumbnailsDirectory: URL,
        maxImageSizeInBytes: Int = DefaultSettings.maxImageSizeInBytes,
        maxImageSizeInBytesProvider: (() -> Int)? = nil,
        fileManager: FileManager = .default,
        thumbnailMaxDimension: CGFloat = 160
    ) {
        self.imagesDirectory = imagesDirectory
        self.thumbnailsDirectory = thumbnailsDirectory
        self.maxImageSizeInBytesProvider = maxImageSizeInBytesProvider ?? { maxImageSizeInBytes }
        self.fileManager = fileManager
        self.thumbnailMaxDimension = thumbnailMaxDimension
    }

    func storeImage(_ candidate: ClipboardImageCandidate) throws -> StoredClipboardImage {
        guard candidate.pngData.count <= maxImageSizeInBytesProvider() else {
            throw ImageStorageError.imageTooLarge
        }
        guard Self.isValidImageData(candidate.pngData) else {
            throw ImageStorageError.invalidImageData
        }

        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

        let contentHash = hash(candidate.pngData)
        let fileURL = imagesDirectory.appendingPathComponent("\(contentHash).png", isDirectory: false)
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(contentHash).png", isDirectory: false)
        try candidate.pngData.write(to: fileURL, options: .atomic)
        try thumbnailData(from: candidate.pngData).write(to: thumbnailURL, options: .atomic)

        return StoredClipboardImage(
            fileURL: fileURL,
            thumbnailURL: thumbnailURL,
            contentHash: contentHash,
            fileSize: candidate.pngData.count,
            width: candidate.width,
            height: candidate.height,
            format: candidate.format
        )
    }

    func deleteImageFiles(for item: ClipboardHistoryItem) {
        deleteImageFiles(filePath: item.filePath, thumbnailPath: item.thumbnailPath)
    }

    func deleteImageFiles(filePath: String?, thumbnailPath: String?) {
        PreviewImageCache.shared.removeImages(forPath: filePath)
        PreviewImageCache.shared.removeImages(forPath: thumbnailPath)
        deleteManagedFile(atPath: filePath, within: imagesDirectory)
        deleteManagedFile(atPath: thumbnailPath, within: thumbnailsDirectory)
    }

    func deleteAllFiles() throws {
        PreviewImageCache.shared.removeAll()
        try deleteContents(of: imagesDirectory)
        try deleteContents(of: thumbnailsDirectory)
    }

    func regenerateThumbnail(from originalURL: URL, to thumbnailURL: URL) throws {
        let originalData = try Data(contentsOf: originalURL)
        guard Self.isValidImageData(originalData) else {
            throw ImageStorageError.invalidImageData
        }
        try fileManager.createDirectory(
            at: thumbnailURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try thumbnailData(from: originalData).write(to: thumbnailURL, options: .atomic)
        PreviewImageCache.shared.removeImages(forPath: thumbnailURL.path)
    }

    private func thumbnailData(from pngData: Data) throws -> Data {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(pngData as CFData, sourceOptions) else {
            throw ImageStorageError.invalidImageData
        }

        let maxPixelSize = max(1, Int(ceil(thumbnailMaxDimension)))
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw ImageStorageError.invalidImageData
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageStorageError.thumbnailEncodingFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageStorageError.thumbnailEncodingFailed
        }
        return mutableData as Data
    }

    private static func isValidImageData(_ data: Data) -> Bool {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateImageAtIndex(source, 0, options) != nil else {
            return false
        }
        return true
    }

    private func hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func deleteManagedFile(atPath path: String?, within root: URL) {
        guard let path, isConcreteManagedDirectory(root) else { return }
        let candidate = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        guard candidate.path.hasPrefix(canonicalRoot.path + "/") else { return }
        try? fileManager.removeItem(atPath: path)
    }

    private func deleteContents(of root: URL) throws {
        guard isConcreteManagedDirectory(root) else { return }
        let files = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        for file in files {
            deleteManagedFile(atPath: file.path, within: root)
        }
    }

    private func isConcreteManagedDirectory(_ root: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: root.path),
              let fileType = attributes[.type] as? FileAttributeType else {
            return false
        }
        return fileType == .typeDirectory
    }
}
