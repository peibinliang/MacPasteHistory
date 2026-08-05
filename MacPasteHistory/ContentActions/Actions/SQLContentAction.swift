import Foundation

struct SQLContentAction: ContentAction {
    let id = ContentActionID(rawValue: "sql.single-line")
    let titleKey = "sql.single-line"; let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [.sql, .plainText]
    func validate(input: String) -> ActionValidationResult { .valid }
    func execute(input: String) throws -> ContentActionResult {
        var output = ""; var quote: Character?; var whitespace = false
        for character in input {
            if let activeQuote = quote { output.append(character); if character == activeQuote { quote = nil }; continue }
            if character == "'" || character == "\"" || character == "`" { if whitespace && !output.isEmpty { output.append(" ") }; whitespace = false; quote = character; output.append(character) }
            else if character.isWhitespace { whitespace = true }
            else { if whitespace && !output.isEmpty { output.append(" ") }; whitespace = false; output.append(character) }
        }
        return ContentActionResult(output: output, syntax: .sql, notices: [], copyVariants: [])
    }
}
