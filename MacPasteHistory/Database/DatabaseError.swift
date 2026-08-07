import Foundation

enum DatabaseError: LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case executeFailed(String)
    case bindFailed(String)
    case stepFailed(String)
    case invalidDate(String)
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "Failed to open database: \(message)"
        case .prepareFailed(let message):
            return "Failed to prepare SQL: \(message)"
        case .executeFailed(let message):
            return "Failed to execute SQL: \(message)"
        case .bindFailed(let message):
            return "Failed to bind SQL parameter: \(message)"
        case .stepFailed(let message):
            return "Failed to step SQL statement: \(message)"
        case .invalidDate(let value):
            return "Invalid database date value: \(value)"
        case .invalidInput(let message):
            return "Invalid database input: \(message)"
        }
    }
}
