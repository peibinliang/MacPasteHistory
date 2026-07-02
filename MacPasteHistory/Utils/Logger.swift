import Foundation
import os

struct Logger {
    private let logger: os.Logger

    init(category: String) {
        self.logger = os.Logger(subsystem: "com.peibin.MacPasteHistory", category: category)
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
