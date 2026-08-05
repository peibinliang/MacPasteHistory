import Foundation

protocol SearchCandidateProviding: Sendable {
    func candidates(for request: SearchCandidateRequest) async throws -> [ClipboardHistoryItem]
}

actor SearchCandidateProvider: SearchCandidateProviding {
    private let databaseURL: URL

    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    func candidates(for request: SearchCandidateRequest) throws -> [ClipboardHistoryItem] {
        let readConnection = try DatabaseConnection(databaseURL: databaseURL, mode: .readOnly)
        defer { try? readConnection.close() }
        let repository = ClipboardHistoryRepository(database: readConnection)
        return try repository.fetchSearchCandidates(request: request)
    }
}
