import Foundation

struct SQLContentAction: ContentAction {
    let id = ContentActionID(rawValue: "sql.single-line")
    let titleKey = "sql.single-line"
    let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [.sql, .plainText]

    func validate(input: String) -> ActionValidationResult { .valid }

    func execute(input: String) throws -> ContentActionResult {
        enum State: Equatable {
            case normal
            case quoted(Character)
            case lineComment
            case blockComment
        }

        let characters = Array(input)
        var output = ""
        var state = State.normal
        var pendingWhitespace = false
        var index = 0

        func appendingPendingWhitespace(to value: inout String) {
            if pendingWhitespace, value.isEmpty == false, value.last != "\n" {
                value.append(" ")
            }
        }

        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil

            switch state {
            case .normal:
                if character.isWhitespace {
                    pendingWhitespace = true
                    index += 1
                } else if character == "-", next == "-" {
                    appendingPendingWhitespace(to: &output)
                    pendingWhitespace = false
                    output.append("--")
                    state = .lineComment
                    index += 2
                } else if character == "/", next == "*" {
                    appendingPendingWhitespace(to: &output)
                    pendingWhitespace = false
                    output.append("/*")
                    state = .blockComment
                    index += 2
                } else {
                    appendingPendingWhitespace(to: &output)
                    pendingWhitespace = false
                    output.append(character)
                    if character == "'" || character == "\"" || character == "`" {
                        state = .quoted(character)
                    }
                    index += 1
                }

            case let .quoted(quote):
                output.append(character)
                if character == quote, next == quote {
                    output.append(quote)
                    index += 2
                } else {
                    if character == quote { state = .normal }
                    index += 1
                }

            case .lineComment:
                output.append(character)
                index += 1
                if character == "\n" {
                    state = .normal
                    pendingWhitespace = false
                }

            case .blockComment:
                output.append(character)
                if character == "*", next == "/" {
                    output.append("/")
                    state = .normal
                    index += 2
                } else {
                    index += 1
                }
            }
        }

        return ContentActionResult(output: output, syntax: .sql, notices: [], copyVariants: [])
    }
}
