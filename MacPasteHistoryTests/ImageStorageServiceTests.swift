import AppKit
import XCTest
@testable import MacPasteHistory

final class ImageStorageServiceTests: XCTestCase {
    private var rootURL: URL!
    private var imagesURL: URL!
    private var thumbnailsURL: URL!
    private var service: ImageStorageService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        imagesURL = rootURL.appendingPathComponent("images", isDirectory: true)
        thumbnailsURL = rootURL.appendingPathComponent("thumbnails", isDirectory: true)
        service = ImageStorageService(imagesDirectory: imagesURL, thumbnailsDirectory: thumbnailsURL)
    }

    override func tearDownWithError() throws {
        service = nil
        if let rootURL {
            try? FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        imagesURL = nil
        thumbnailsURL = nil
        try super.tearDownWithError()
    }

    func testStoreImage_shouldCreateOriginalAndThumbnailFiles() throws {
        let candidate = try makeCandidate(width: 32, height: 20)

        let storedImage = try service.storeImage(candidate)

        XCTAssertTrue(FileManager.default.fileExists(atPath: storedImage.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storedImage.thumbnailURL.path))
        XCTAssertEqual(storedImage.width, 32)
        XCTAssertEqual(storedImage.height, 20)
        XCTAssertEqual(storedImage.format, .png)
        XCTAssertFalse(storedImage.contentHash.isEmpty)
        XCTAssertGreaterThan(storedImage.fileSize, 0)
    }

    func testStoreImage_whenImageExceedsLimit_shouldNotLeaveFilesBehind() throws {
        let candidate = try makeCandidate(width: 32, height: 20)
        service = ImageStorageService(imagesDirectory: imagesURL, thumbnailsDirectory: thumbnailsURL, maxImageSizeInBytes: 1)

        XCTAssertThrowsError(try service.storeImage(candidate))
        XCTAssertFalse(FileManager.default.fileExists(atPath: imagesURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbnailsURL.path))
    }

    func testStoreImage_whenLimitProviderChanges_shouldUseLatestLimit() throws {
        let candidate = try makeCandidate(width: 32, height: 20)
        var maxImageSizeInBytes = candidate.pngData.count + 1
        service = ImageStorageService(
            imagesDirectory: imagesURL,
            thumbnailsDirectory: thumbnailsURL,
            maxImageSizeInBytesProvider: { maxImageSizeInBytes }
        )

        _ = try service.storeImage(candidate)
        maxImageSizeInBytes = 1

        XCTAssertThrowsError(try service.storeImage(candidate))
    }

    private func makeCandidate(width: Int, height: Int) throws -> ClipboardImageCandidate {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.systemPink.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw TestImageError.encodingFailed
        }

        return ClipboardImageCandidate(pngData: pngData, width: width, height: height, format: .png)
    }
}

private enum TestImageError: Error {
    case encodingFailed
}
