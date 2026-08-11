import Foundation
import Security

enum AICredentialStoreError: Error, Equatable {
    case invalidCredential
    case invalidStoredData
    case keychainFailure(OSStatus)
}

protocol AICredentialStoring: Sendable {
    func readAPIKey() throws -> String?
    func hasAPIKey() throws -> Bool
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

protocol KeychainCredentialBackend: Sendable {
    func read(service: String, account: String) throws -> Data?
    func add(_ data: Data, service: String, account: String) throws
    func update(_ data: Data, service: String, account: String) throws
    func delete(service: String, account: String) throws
}

final class KeychainAICredentialStore: AICredentialStoring, @unchecked Sendable {
    static let serviceIdentifier = "com.peibin.MacPasteHistory.ai"
    static let accountIdentifier = "deepseek-api-key"

    private let backend: any KeychainCredentialBackend

    init(backend: any KeychainCredentialBackend = SystemKeychainCredentialBackend()) {
        self.backend = backend
    }

    func readAPIKey() throws -> String? {
        guard let data = try backend.read(
            service: Self.serviceIdentifier,
            account: Self.accountIdentifier
        ) else {
            return nil
        }
        guard let value = String(data: data, encoding: .utf8), value.isEmpty == false else {
            throw AICredentialStoreError.invalidStoredData
        }
        return value
    }

    func hasAPIKey() throws -> Bool {
        try readAPIKey() != nil
    }

    func saveAPIKey(_ apiKey: String) throws {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false, let data = value.data(using: .utf8) else {
            throw AICredentialStoreError.invalidCredential
        }
        if try backend.read(service: Self.serviceIdentifier, account: Self.accountIdentifier) == nil {
            try backend.add(data, service: Self.serviceIdentifier, account: Self.accountIdentifier)
        } else {
            try backend.update(data, service: Self.serviceIdentifier, account: Self.accountIdentifier)
        }
    }

    func deleteAPIKey() throws {
        try backend.delete(service: Self.serviceIdentifier, account: Self.accountIdentifier)
    }
}

struct SystemKeychainCredentialBackend: KeychainCredentialBackend {
    func read(service: String, account: String) throws -> Data? {
        var result: CFTypeRef?
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw AICredentialStoreError.keychainFailure(status)
        }
        guard let data = result as? Data else {
            throw AICredentialStoreError.invalidStoredData
        }
        return data
    }

    func add(_ data: Data, service: String, account: String) throws {
        var query = baseQuery(service: service, account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AICredentialStoreError.keychainFailure(status)
        }
    }

    func update(_ data: Data, service: String, account: String) throws {
        let status = SecItemUpdate(
            baseQuery(service: service, account: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        guard status == errSecSuccess else {
            throw AICredentialStoreError.keychainFailure(status)
        }
    }

    func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AICredentialStoreError.keychainFailure(status)
        }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
