import Foundation

struct ContentSemanticToken: Equatable {
    let range: Range<String.Index>
    let kind: String
}

struct ContentSyntaxHighlighter {
    func tokens(for text: String, syntax: ContentSyntax) -> [ContentSemanticToken] {
        let patterns: [(kind: String, pattern: String, options: NSRegularExpression.Options)]
        switch syntax {
        case .json, .jwt:
            patterns = [
                ("key", #""(?:\\.|[^"\\])*"(?=\s*:)"#, []),
                ("string", #""(?:\\.|[^"\\])*""#, []),
                ("number", #"(?<![A-Za-z0-9_])-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?"#, []),
                ("boolean", #"\b(?:true|false)\b"#, []),
                ("null", #"\bnull\b"#, [])
            ]
        case .sql:
            patterns = [
                ("comment", #"--[^\n]*|/\*[\s\S]*?\*/"#, []),
                ("string", #"'(?:''|[^'])*'|"(?:""|[^"])*"|`(?:``|[^`])*`"#, []),
                ("number", #"\b\d+(?:\.\d+)?\b"#, []),
                ("keyword", #"\b(?:SELECT|FROM|WHERE|UPDATE|SET|INSERT|INTO|DELETE|VALUES|JOIN|ON|GROUP|BY|ORDER|HAVING|LIMIT|AS|AND|OR|NOT|NULL)\b"#, [.caseInsensitive])
            ]
        case .plainText:
            return []
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return patterns.flatMap { definition -> [ContentSemanticToken] in
            guard let regex = try? NSRegularExpression(
                pattern: definition.pattern,
                options: definition.options
            ) else { return [] }
            return regex.matches(in: text, range: fullRange).compactMap { match in
                guard let range = Range(match.range, in: text) else { return nil }
                return ContentSemanticToken(range: range, kind: definition.kind)
            }
        }.sorted { lhs, rhs in
            lhs.range.lowerBound < rhs.range.lowerBound
        }
    }
}
