import AppKit
import Foundation

final class ClipboardReader {
    private let pasteboard: PasteboardProviding

    init(pasteboard: PasteboardProviding = NSPasteboard.general) {
        self.pasteboard = pasteboard
    }

    func readPlainText() -> String? {
        guard let text = pasteboard.string(forType: .string) else {
            return nil
        }

        let sanitizedText = sanitize(text)
        guard sanitizedText.isEmpty == false else {
            return nil
        }
        return sanitizedText
    }

    func readImage() -> ClipboardImageCandidate? {
        if let pngData = pasteboard.data(forType: .png) {
            return makeImageCandidate(fromPNGData: pngData)
        }

        if let tiffData = pasteboard.data(forType: .tiff) {
            return makeImageCandidate(fromTIFFData: tiffData)
        }

        if let fileImage = readImageFile() {
            return fileImage
        }

        return nil
    }

    private func sanitize(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            CharacterSet.controlCharacters.contains(scalar) == false || scalar == "\n" || scalar == "\t"
        }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeImageCandidate(fromPNGData pngData: Data) -> ClipboardImageCandidate? {
        guard let bitmap = NSBitmapImageRep(data: pngData) else {
            return nil
        }
        return ClipboardImageCandidate(
            pngData: pngData,
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh,
            format: .png
        )
    }

    private func makeImageCandidate(fromTIFFData tiffData: Data) -> ClipboardImageCandidate? {
        guard let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return ClipboardImageCandidate(
            pngData: pngData,
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh,
            format: .png
        )
    }

    private func readImageFile() -> ClipboardImageCandidate? {
        pasteboard.fileURLs()
            .lazy
            .compactMap { self.makeImageCandidate(fromFileURL: $0) }
            .first
    }

    private func makeImageCandidate(fromFileURL fileURL: URL) -> ClipboardImageCandidate? {
        guard isSupportedImageFile(fileURL),
              let data = try? Data(contentsOf: fileURL),
              let bitmap = NSBitmapImageRep(data: data),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        return ClipboardImageCandidate(
            pngData: pngData,
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh,
            format: .png
        )
    }

    private func isSupportedImageFile(_ fileURL: URL) -> Bool {
        let supportedExtensions = ["heic", "jpeg", "jpg", "png", "tif", "tiff"]
        return supportedExtensions.contains(fileURL.pathExtension.lowercased())
    }
}
