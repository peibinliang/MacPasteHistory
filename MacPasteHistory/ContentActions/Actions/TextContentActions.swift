import Foundation

struct TextContentAction: ContentAction {
    enum Kind: String, CaseIterable { case trim, removeEmptyLines, deduplicateLines, singleLine, uppercase, lowercase, markdownCodeBlock }
    let kind: Kind

    var id: ContentActionID { ContentActionID(rawValue: "text." + identifier) }
    var titleKey: String { id.rawValue }
    var category: ContentActionCategory { .text }
    var supportedTypes: Set<DetectedContentType> { Set(DetectedContentType.allCases).subtracting([.image]) }

    func validate(input: String) -> ActionValidationResult { .valid }

    func execute(input: String) throws -> ContentActionResult {
        let output: String
        switch kind {
        case .trim: output = input.trimmingCharacters(in: .whitespacesAndNewlines)
        case .removeEmptyLines: output = input.split(separator: "\n", omittingEmptySubsequences: false).filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.joined(separator: "\n")
        case .deduplicateLines:
            var seen = Set<String>(); output = input.split(separator: "\n", omittingEmptySubsequences: false).filter { seen.insert(String($0)).inserted }.joined(separator: "\n")
        case .singleLine: output = input.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        case .uppercase: output = input.uppercased(with: Locale(identifier: "en_US_POSIX"))
        case .lowercase: output = input.lowercased(with: Locale(identifier: "en_US_POSIX"))
        case .markdownCodeBlock: output = "```\n\(input)\n```"
        }
        return ContentActionResult(output: output, syntax: .plainText, notices: [], copyVariants: [])
    }

    private var identifier: String {
        switch kind {
        case .trim: "trim"; case .removeEmptyLines: "remove-empty-lines"; case .deduplicateLines: "deduplicate-lines"; case .singleLine: "single-line"; case .uppercase: "uppercase"; case .lowercase: "lowercase"; case .markdownCodeBlock: "markdown-code-block"
        }
    }
}
