import Foundation

@testable import MacPasteHistory

final class TemporaryDatabase {
    let url: URL
    let connection: DatabaseConnection

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        connection = try DatabaseConnection(databaseURL: url)
    }

    func remove() {
        try? connection.close()
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
    }
}
