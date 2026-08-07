import Foundation

struct SQLContentAction: ContentAction {
    let id = ContentActionID(rawValue: "sql.single-line")
    let titleKey = "sql.single-line"
    let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [.sql, .plainText]

    func validate(input: String) -> ActionValidationResult { .valid }

    func execute(input: String) throws -> ContentActionResult {
        let characters = Array(input)
        var output = ""
        var index = 0
        var quote: Character?
        var inLineComment = false
        var inBlockComment = false
        var pendingWhitespace = false

        func nextCharacter() -> Character? {
            let nextIndex = index + 1
            return nextIndex < characters.count ? characters[nextIndex] : nil
        }

        func appendPendingWhitespace() {
            guard pendingWhitespace, output.isEmpty == false, output.last != "\n" else {
                pendingWhitespace = false
                return
            }
            output.append(" ")
            pendingWhitespace = false
        }

        while index < characters.count {
            let character = characters[index]
            let next = nextCharacter()

            if inLineComment {
                output.append(character)
                if character == "\n" { inLineComment = false }
                index += 1
                continue
            }
            if inBlockComment {
                output.append(character)
                if character == "*", next == "/" {
                    output.append("/")
                    index += 2
                    inBlockComment = false
                } else {
                    index += 1
                }
                continue
            }
            if let activeQuote = quote {
                output.append(character)
                if character == activeQuote {
                    if next == activeQuote {
                        output.append(activeQuote)
                        index += 2
                        continue
                    }
                    quote = nil
                }
                index += 1
                continue
            }

            if character == "-", next == "-" {
                appendPendingWhitespace()
                output.append("--")
                index += 2
                inLineComment = true
            } else if character == "/", next == "*" {
                appendPendingWhitespace()
                output.append("/*")
                index += 2
                inBlockComment = true
            } else if character == "'" || character == "\"" || character == "`" {
                appendPendingWhitespace()
                quote = character
                output.append(character)
                index += 1
            } else if character.isWhitespace {
                pendingWhitespace = true
                index += 1
            } else {
                appendPendingWhitespace()
                output.append(character)
                index += 1
            }
        }

        return ContentActionResult(output: output, syntax: .sql, notices: [], copyVariants: [])
    }
}
