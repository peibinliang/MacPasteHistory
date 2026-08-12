import Foundation
import Security
import XCTest
@testable import MacPasteHistory

final class AICredentialStoreTests: XCTestCase {
    func testSaveReadAndDelete_shouldUseStableKeychainIdentity() throws {
        let backend = FakeKeychainCredentialBackend()
        let store = KeychainAICredentialStore(backend: backend)

        try store.saveAPIKey("fake-key-for-tests")

        XCTAssertEqual(try store.readAPIKey(), "fake-key-for-tests")
        XCTAssertTrue(try store.hasAPIKey())
        XCTAssertEqual(backend.lastService, KeychainAICredentialStore.serviceIdentifier)
        XCTAssertEqual(backend.lastAccount, KeychainAICredentialStore.accountIdentifier)

        try store.deleteAPIKey()
        XCTAssertFalse(try store.hasAPIKey())
    }

    func testSave_whenReplacingCredentialFails_shouldPreserveExistingValue() throws {
        let backend = FakeKeychainCredentialBackend()
        let store = KeychainAICredentialStore(backend: backend)
        try store.saveAPIKey("old-fake-key")
        backend.shouldFailUpdate = true

        XCTAssertThrowsError(try store.saveAPIKey("new-fake-key"))
        XCTAssertEqual(try store.readAPIKey(), "old-fake-key")
    }

    func testSave_whenCredentialIsBlank_shouldRejectWithoutPlaintextFallback() {
        let backend = FakeKeychainCredentialBackend()
        let store = KeychainAICredentialStore(backend: backend)

        XCTAssertThrowsError(try store.saveAPIKey("  \n"))
        XCTAssertNil(backend.data)
    }
}

final class LocalFileAICredentialStoreTests: XCTestCase {
    private var rootDirectoryURL: URL?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let rootDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalFileAICredentialStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: rootDirectoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        self.rootDirectoryURL = rootDirectoryURL
    }

    override func tearDownWithError() throws {
        if let rootDirectoryURL {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootDirectoryURL.path)
            try? FileManager.default.removeItem(at: rootDirectoryURL)
        }
        rootDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testSaveReadReloadAndDelete_shouldTrimAndPersistCredential() throws {
        let credentialURL = try makeCredentialURL()
        let store = LocalFileAICredentialStore(fileURL: credentialURL)

        try store.saveAPIKey("  fake-local-key-for-tests  \n")

        XCTAssertEqual(try store.readAPIKey(), "fake-local-key-for-tests")
        XCTAssertTrue(try store.hasAPIKey())
        XCTAssertEqual(
            try LocalFileAICredentialStore(fileURL: credentialURL).readAPIKey(),
            "fake-local-key-for-tests"
        )

        try store.deleteAPIKey()

        XCTAssertNil(try store.readAPIKey())
        XCTAssertFalse(try store.hasAPIKey())
        XCTAssertFalse(FileManager.default.fileExists(atPath: credentialURL.path))
        XCTAssertNoThrow(try store.deleteAPIKey())
    }

    func testSave_shouldApplyOwnerOnlyPermissionsToNewAndReplacedCredential() throws {
        let credentialURL = try makeCredentialURL()
        let store = LocalFileAICredentialStore(fileURL: credentialURL)

        try store.saveAPIKey("first-fake-key")
        XCTAssertEqual(try posixPermissions(at: credentialURL), 0o600)

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: credentialURL.path)
        try store.saveAPIKey("replacement-fake-key")

        XCTAssertEqual(try store.readAPIKey(), "replacement-fake-key")
        XCTAssertEqual(try posixPermissions(at: credentialURL), 0o600)
    }

    func testSave_whenAtomicReplacementCannotBePrepared_shouldPreserveExistingCredential() throws {
        let rootDirectoryURL = try requireRootDirectoryURL()
        let credentialURL = rootDirectoryURL.appendingPathComponent("credential")
        let store = LocalFileAICredentialStore(fileURL: credentialURL)
        try store.saveAPIKey("old-fake-key")
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: rootDirectoryURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootDirectoryURL.path)
        }

        XCTAssertThrowsError(try store.saveAPIKey("new-fake-key"))
        XCTAssertEqual(try Data(contentsOf: credentialURL), Data("old-fake-key".utf8))
    }

    func testSave_shouldAtomicallyReplaceFileAndLeaveNoTemporarySibling() throws {
        let credentialURL = try makeCredentialURL()
        let store = LocalFileAICredentialStore(fileURL: credentialURL)
        try store.saveAPIKey("old-fake-key")
        let originalFileNumber = try fileNumber(at: credentialURL)

        try store.saveAPIKey("new-and-longer-fake-key")

        XCTAssertNotEqual(try fileNumber(at: credentialURL), originalFileNumber)
        XCTAssertEqual(try store.readAPIKey(), "new-and-longer-fake-key")
        let siblingNames = try FileManager.default.contentsOfDirectory(
            at: credentialURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent)
        XCTAssertEqual(siblingNames, [credentialURL.lastPathComponent])
    }

    func testSave_whenCredentialIsBlank_shouldRejectWithoutCreatingFile() throws {
        let credentialURL = try makeCredentialURL()
        let store = LocalFileAICredentialStore(fileURL: credentialURL)

        XCTAssertThrowsError(try store.saveAPIKey("  \n\t ")) { error in
            XCTAssertEqual(error as? AICredentialStoreError, .invalidCredential)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: credentialURL.path))
    }

    func testSave_whenCredentialExceedsLimit_shouldRejectWithoutReplacingExistingValue() throws {
        let credentialURL = try makeCredentialURL()
        let store = LocalFileAICredentialStore(fileURL: credentialURL, maximumCredentialSizeInBytes: 16)
        try store.saveAPIKey("old-fake-key")

        XCTAssertThrowsError(try store.saveAPIKey(String(repeating: "x", count: 17))) { error in
            XCTAssertEqual(error as? AICredentialStoreError, .invalidCredential)
        }
        XCTAssertEqual(try store.readAPIKey(), "old-fake-key")
    }

    func testRead_whenStoredDataExceedsLimit_shouldReject() throws {
        let credentialURL = try makeCredentialURL()
        try Data(repeating: 0x61, count: 17).write(to: credentialURL)
        let store = LocalFileAICredentialStore(fileURL: credentialURL, maximumCredentialSizeInBytes: 16)

        XCTAssertThrowsError(try store.readAPIKey()) { error in
            XCTAssertEqual(error as? AICredentialStoreError, .invalidStoredData)
        }
    }

    func testRead_whenStoredDataIsInvalidUTF8_shouldReject() throws {
        let credentialURL = try makeCredentialURL()
        try Data([0xC3, 0x28]).write(to: credentialURL)
        let store = LocalFileAICredentialStore(fileURL: credentialURL)

        XCTAssertThrowsError(try store.readAPIKey()) { error in
            XCTAssertEqual(error as? AICredentialStoreError, .invalidStoredData)
        }
    }

    func testRead_whenStoredCredentialIsBlank_shouldReject() throws {
        let credentialURL = try makeCredentialURL()
        try Data("  \n\t".utf8).write(to: credentialURL)
        let store = LocalFileAICredentialStore(fileURL: credentialURL)

        XCTAssertThrowsError(try store.readAPIKey()) { error in
            XCTAssertEqual(error as? AICredentialStoreError, .invalidStoredData)
        }
    }

    func testReadAndSave_whenCredentialPathIsSymbolicLink_shouldRejectWithoutFollowingLink() throws {
        let rootDirectoryURL = try requireRootDirectoryURL()
        let targetURL = rootDirectoryURL.appendingPathComponent("target")
        let credentialURL = rootDirectoryURL.appendingPathComponent("credential")
        try Data("target-fake-key".utf8).write(to: targetURL)
        try FileManager.default.createSymbolicLink(at: credentialURL, withDestinationURL: targetURL)
        let store = LocalFileAICredentialStore(fileURL: credentialURL)

        XCTAssertThrowsError(try store.readAPIKey()) { error in
            XCTAssertEqual(error as? AICredentialStoreError, .invalidStoredData)
        }
        XCTAssertThrowsError(try store.saveAPIKey("replacement-fake-key"))
        XCTAssertEqual(try Data(contentsOf: targetURL), Data("target-fake-key".utf8))
    }

    func testReadAndSave_whenCredentialPathIsNotARegularFile_shouldReject() throws {
        let credentialURL = try makeCredentialURL()
        try FileManager.default.createDirectory(at: credentialURL, withIntermediateDirectories: false)
        let store = LocalFileAICredentialStore(fileURL: credentialURL)

        XCTAssertThrowsError(try store.readAPIKey()) { error in
            XCTAssertEqual(error as? AICredentialStoreError, .invalidStoredData)
        }
        XCTAssertThrowsError(try store.saveAPIKey("fake-local-key"))
    }

    private func makeCredentialURL() throws -> URL {
        try requireRootDirectoryURL().appendingPathComponent("credential")
    }

    private func requireRootDirectoryURL() throws -> URL {
        try XCTUnwrap(rootDirectoryURL)
    }

    private func posixPermissions(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue
    }

    private func fileNumber(at url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.systemFileNumber] as? NSNumber).uint64Value
    }
}

private final class FakeKeychainCredentialBackend: KeychainCredentialBackend, @unchecked Sendable {
    var data: Data?
    var shouldFailUpdate = false
    private(set) var lastService: String?
    private(set) var lastAccount: String?

    func read(service: String, account: String) throws -> Data? {
        capture(service: service, account: account)
        return data
    }

    func add(_ data: Data, service: String, account: String) throws {
        capture(service: service, account: account)
        self.data = data
    }

    func update(_ data: Data, service: String, account: String) throws {
        capture(service: service, account: account)
        if shouldFailUpdate {
            throw AICredentialStoreError.keychainFailure(errSecAuthFailed)
        }
        self.data = data
    }

    func delete(service: String, account: String) throws {
        capture(service: service, account: account)
        data = nil
    }

    private func capture(service: String, account: String) {
        lastService = service
        lastAccount = account
    }
}
