import Foundation

enum DerivedSourcePreviewBuilder {
    private static let maximumTextLength = 120

    static func build(for item: ClipboardHistoryItem) -> String {
        if item.isSensitive {
            return "Sensitive content"
        }
        if item.contentType == .image {
            return "Image"
        }
        if item.effectiveDetectedType == .jwt {
            return "JWT • \(item.contentHash.prefix(8))"
        }
        if item.effectiveDetectedType == .url, let preview = urlPreview(from: item.textContent) {
            return preview
        }

        let collapsedText = item.textContent
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard collapsedText.isEmpty == false else {
            return "Empty text"
        }
        return String(collapsedText.prefix(maximumTextLength))
    }

    private static func urlPreview(from text: String) -> String? {
        guard var components = URLComponents(string: text),
              let scheme = components.scheme,
              let host = components.host else {
            return nil
        }

        components.query = nil
        components.fragment = nil
        let path = components.percentEncodedPath
        return "\(scheme)://\(host)\(path)"
    }
}
