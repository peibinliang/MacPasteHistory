import Foundation

enum DatabaseInitializationError: LocalizedError {
    case openFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "Failed to open SQLite database: \(message)"
        }
    }
}
