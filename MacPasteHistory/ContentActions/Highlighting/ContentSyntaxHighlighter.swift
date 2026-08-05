import Foundation

struct ContentSemanticToken: Equatable { let range: Range<String.Index>; let kind: String }
struct ContentSyntaxHighlighter {
    func tokens(for text: String, syntax: ContentSyntax) -> [ContentSemanticToken] {
        guard syntax == .json || syntax == .jwt || syntax == .sql else { return [] }
        let pattern = syntax == .sql ? "(?i)\\b(SELECT|FROM|WHERE|UPDATE|SET|INSERT|DELETE)\\b" : "\\\"[^\\\"]+\\\"(?=\\s*:)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return ContentSemanticToken(range: range, kind: syntax == .sql ? "keyword" : "key")
        }
    }
}
