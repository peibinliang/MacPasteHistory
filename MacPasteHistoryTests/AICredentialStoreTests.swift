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
