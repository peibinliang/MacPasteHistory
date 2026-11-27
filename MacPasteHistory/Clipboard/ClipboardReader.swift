import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum RawClipboardImageSource: Sendable {
    case png(Data)
    case jpeg(Data)
    case tiff(Data)
    case imageFileURLs([URL])
    case decodedImage(ClipboardImageCandidate)
}

struct RawClipboardSnapshot: Sendable {
    let imageSource: RawClipboardImageSource?
    let rawText: String?
}

final class ClipboardReader {
    private static let jpegPasteboardType = NSPasteboard.PasteboardType("public.jpeg")
    private static let supportedImageExtensions: Set<String> = ["heic", "jpeg", "jpg", "png", "tif", "tiff"]
    private let pasteboard: PasteboardProviding

    init(pasteboard: PasteboardProviding = NSPasteboard.general) {
        self.pasteboard = pasteboard
    }

    func readRawSnapshot(shouldRecordImage: Bool, shouldRecordText: Bool) -> RawClipboardSnapshot {
        let imageSource: RawClipboardImageSource?
        if shouldRecordImage {
            imageSource = readRawImageSource()
        } else {
            imageSource = nil
        }

        let rawText = shouldRecordText ? pasteboard.string(forType: .string) : nil
        return RawClipboardSnapshot(imageSource: imageSource, rawText: rawText)
    }

    func readPlainText() -> String? {
        guard let text = pasteboard.string(forType: .string) else {
            return nil
        }
        return Self.sanitizePlainText(text)
    }

    func readImage() -> ClipboardImageCandidate? {
        guard let source = readRawImageSource() else {
            return nil
        }
        return Self.decodeImageCandidate(from: source)
    }

    static func sanitizePlainText(_ text: String) -> String? {
        let scalars = text.unicodeScalars.filter { scalar in
            CharacterSet.controlCharacters.contains(scalar) == false || scalar == "\n" || scalar == "\t"
        }
        let sanitizedText = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitizedText.isEmpty ? nil : sanitizedText
    }

    static func decodeImageCandidate(from source: RawClipboardImageSource) -> ClipboardImageCandidate? {
        switch source {
        case let .png(pngData):
            return makeImageCandidate(fromPNGData: pngData)
        case let .jpeg(jpegData):
            return makeImageCandidate(fromEncodedImageData: jpegData)
        case let .tiff(tiffData):
            return makeImageCandidate(fromEncodedImageData: tiffData)
        case let .imageFileURLs(fileURLs):
            return fileURLs.lazy.compactMap { makeImageCandidate(fromFileURL: $0) }.first
        case let .decodedImage(candidate):
            return candidate
        }
    }

    private func readRawImageSource() -> RawClipboardImageSource? {
        if let pngData = pasteboard.data(forType: .png) {
            return .png(pngData)
        }
        if let jpegData = pasteboard.data(forType: Self.jpegPasteboardType) {
            return .jpeg(jpegData)
        }
        if let tiffData = pasteboard.data(forType: .tiff) {
            return .tiff(tiffData)
        }
        let imageFileURLs = pasteboard.fileURLs().filter(Self.isSupportedImageFile)
        if imageFileURLs.isEmpty == false {
            return .imageFileURLs(imageFileURLs)
        }
        if let nsImage = pasteboard.image(),
           let candidate = Self.makeImageCandidate(fromNSImage: nsImage) {
            return .decodedImage(candidate)
        }
        return nil
    }

    private static func makeImageCandidate(fromPNGData pngData: Data) -> ClipboardImageCandidate? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(pngData as CFData, options),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            return nil
        }
        return ClipboardImageCandidate(
            pngData: pngData,
            width: cgImage.width,
            height: cgImage.height,
            format: .png
        )
    }

    private static func makeImageCandidate(fromEncodedImageData imageData: Data) -> ClipboardImageCandidate? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(imageData as CFData, options),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options),
              let pngData = encodePNG(from: cgImage) else {
            return nil
        }
        return ClipboardImageCandidate(
            pngData: pngData,
            width: cgImage.width,
            height: cgImage.height,
            format: .png
        )
    }

    private static func makeImageCandidate(fromNSImage nsImage: NSImage) -> ClipboardImageCandidate? {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let pngData = encodePNG(from: cgImage) else {
            return nil
        }
        return ClipboardImageCandidate(
            pngData: pngData,
            width: cgImage.width,
            height: cgImage.height,
            format: .png
        )
    }

    private static func makeImageCandidate(fromFileURL fileURL: URL) -> ClipboardImageCandidate? {
        guard isSupportedImageFile(fileURL),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return makeImageCandidate(fromEncodedImageData: data)
    }

    private static func encodePNG(from cgImage: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }

    private static func isSupportedImageFile(_ fileURL: URL) -> Bool {
        supportedImageExtensions.contains(fileURL.pathExtension.lowercased())
    }
}
