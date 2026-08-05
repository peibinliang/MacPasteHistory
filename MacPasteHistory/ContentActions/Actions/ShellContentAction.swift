import Foundation

struct ShellContentAction: ContentAction {
    let id = ContentActionID(rawValue: "shell.quote-argument")
    let titleKey = "shell.quote-argument"
    let category: ContentActionCategory = .text
    let supportedTypes: Set<DetectedContentType> = [.shell, .plainText]
    func validate(input: String) -> ActionValidationResult { .valid }
    func execute(input: String) throws -> ContentActionResult {
        let output = "'" + input.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return ContentActionResult(output: output, syntax: .plainText, notices: [], copyVariants: [])
    }
}
