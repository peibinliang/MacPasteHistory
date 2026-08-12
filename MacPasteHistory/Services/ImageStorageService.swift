import AppKit
import CryptoKit
import Foundation

enum ImageStorageError: Error {
    case invalidImageData
    case imageTooLarge
    case thumbnailEncodingFailed
}

final class ImageStorageService {
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
        guard NSImage(data: candidate.pngData) != nil else {
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
        deleteManagedFile(atPath: filePath, within: imagesDirectory)
        deleteManagedFile(atPath: thumbnailPath, within: thumbnailsDirectory)
    }

    func deleteAllFiles() throws {
        try deleteContents(of: imagesDirectory)
        try deleteContents(of: thumbnailsDirectory)
    }

    func regenerateThumbnail(from originalURL: URL, to thumbnailURL: URL) throws {
        let originalData = try Data(contentsOf: originalURL)
        guard NSImage(data: originalData) != nil else {
            throw ImageStorageError.invalidImageData
        }
        try fileManager.createDirectory(
            at: thumbnailURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try thumbnailData(from: originalData).write(to: thumbnailURL, options: .atomic)
    }

    private func thumbnailData(from pngData: Data) throws -> Data {
        guard let image = NSImage(data: pngData) else {
            throw ImageStorageError.invalidImageData
        }

        let sourceSize = image.size
        let scale = min(thumbnailMaxDimension / max(sourceSize.width, 1), thumbnailMaxDimension / max(sourceSize.height, 1), 1)
        let targetSize = NSSize(width: max(1, sourceSize.width * scale), height: max(1, sourceSize.height * scale))
        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        thumbnail.unlockFocus()

        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageStorageError.thumbnailEncodingFailed
        }
        return data
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
