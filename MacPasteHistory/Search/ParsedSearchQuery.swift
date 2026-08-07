import Foundation

struct ParsedSearchQuery: Equatable {
    let rawInput: String
    let terms: [String]
    let app: String?
    let type: DetectedContentType?
    let favorite: Bool?
    let before: Date?
    let after: Date?
    let tokens: [SearchToken]
    let issues: [SearchParseIssue]
}

struct SearchToken: Equatable {
    let kind: SearchTokenKind
    let range: Range<String.Index>
}

enum SearchTokenKind: Equatable {
    case app(String)
    case type(DetectedContentType)
    case favorite(Bool)
    case before(Date)
    case after(Date)
    case invalid(prefix: String, value: String)

    var dimension: SearchTokenDimension? {
        switch self {
        case .app:
            return .app
        case .type:
            return .type
        case .favorite:
            return .favorite
        case .before:
            return .before
        case .after:
            return .after
        case .invalid:
            return nil
        }
    }
}

struct SearchParseIssue: Equatable {
    enum Kind: Equatable {
        case invalidValue
        case unterminatedQuote
    }

    let kind: Kind
    let range: Range<String.Index>
}

enum SearchTokenDimension: Equatable {
    case app
    case type
    case favorite
    case before
    case after
}
