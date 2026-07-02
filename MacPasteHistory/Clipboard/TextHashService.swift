import CryptoKit
import Foundation

final class TextHashService {
    func hash(for text: String) -> String {
        let normalizedText = normalize(text)
        let digest = SHA256.hash(data: Data(normalizedText.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
