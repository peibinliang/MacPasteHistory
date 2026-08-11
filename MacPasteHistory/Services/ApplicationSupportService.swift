import Foundation

final class ApplicationSupportService {
    private let fileManager: FileManager
    private let applicationSupportOverrideURL: URL?

    init(fileManager: FileManager = .default, applicationSupportOverrideURL: URL? = nil) {
        self.fileManager = fileManager
        self.applicationSupportOverrideURL = applicationSupportOverrideURL
    }

    var applicationSupportURL: URL {
        get throws {
            if let applicationSupportOverrideURL {
                return applicationSupportOverrideURL
            }
            return try fileManager.url(
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

    var reconciliationTemporaryURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("temporary", isDirectory: true)
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
        try createDirectory(at: reconciliationTemporaryURL)
        try createDirectory(at: logsURL)
    }

    private func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
