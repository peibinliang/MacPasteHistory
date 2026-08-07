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
                ("number", #"(?<![\w.])-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, []),
                ("boolean", #"\b(?:true|false)\b"#, []),
                ("null", #"\bnull\b"#, [])
            ]
        case .sql:
            patterns = [
                ("comment", #"--[^\n]*|/\*.*?\*/"#, [.dotMatchesLineSeparators]),
                ("string", #"'(?:''|[^'])*'|"(?:""|[^"])*"|`(?:``|[^`])*`"#, []),
                ("keyword", #"\b(?:SELECT|FROM|WHERE|UPDATE|SET|INSERT|INTO|DELETE|VALUES|JOIN|ON|GROUP|BY|ORDER|HAVING|LIMIT|OFFSET|AS|AND|OR|NOT|NULL|IS)\b"#, [.caseInsensitive]),
                ("number", #"(?<![\w.])-?\b\d+(?:\.\d+)?\b"#, [])
            ]
        case .plainText:
            return []
        }

        var tokens: [ContentSemanticToken] = []
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for entry in patterns {
            guard let regex = try? NSRegularExpression(pattern: entry.pattern, options: entry.options) else {
                continue
            }
            for match in regex.matches(in: text, range: fullRange) {
                guard let range = Range(match.range, in: text),
                      tokens.contains(where: { $0.range.overlaps(range) }) == false else {
                    continue
                }
                tokens.append(ContentSemanticToken(range: range, kind: entry.kind))
            }
        }
        return tokens.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
}
