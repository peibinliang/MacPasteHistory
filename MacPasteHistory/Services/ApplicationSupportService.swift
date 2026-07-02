import Foundation

final class ApplicationSupportService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var applicationSupportURL: URL {
        get throws {
            try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            .appendingPathComponent("MacPasteHistory", isDirectory: true)
        }
    }

    var databaseURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("clipboard.db", isDirectory: false)
        }
    }

    var imagesURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("images", isDirectory: true)
        }
    }

    var thumbnailsURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("thumbnails", isDirectory: true)
        }
    }

    var logsURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("logs", isDirectory: true)
        }
    }

    func createRequiredDirectories() throws {
        try createDirectory(at: applicationSupportURL)
        try createDirectory(at: imagesURL)
        try createDirectory(at: thumbnailsURL)
        try createDirectory(at: logsURL)
    }

    private func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
