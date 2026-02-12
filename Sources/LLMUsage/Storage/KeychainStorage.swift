import Foundation
import Security

/// Keychain-based storage for secure token persistence
public final class KeychainStorage: AccountStorage, @unchecked Sendable {
    private let service: String
    private let accountsKey = "llmusage.accounts"
    private let queue = DispatchQueue(label: "llmusage.keychain", qos: .userInitiated)
    
    public init(service: String = "com.phimage.llmusage") {
        self.service = service
    }
    
    // MARK: - AccountStorage
    
    public func loadAccounts() async throws -> [LLMAccount] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let accounts = try self.readAccountsSync()
                    continuation.resume(returning: accounts)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func saveAccounts(_ accounts: [LLMAccount]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.writeAccountsSync(accounts)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func loadAccount(id: UUID) async throws -> LLMAccount? {
        let accounts = try await loadAccounts()
        return accounts.first { $0.id == id }
    }
    
    public func saveAccount(_ account: LLMAccount) async throws {
        var accounts = try await loadAccounts()
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
        try await saveAccounts(accounts)
    }
    
    public func deleteAccount(id: UUID) async throws {
        var accounts = try await loadAccounts()
        accounts.removeAll { $0.id == id }
        try await saveAccounts(accounts)
    }
    
    // MARK: - Keychain Operations
    
    private func readAccountsSync() throws -> [LLMAccount] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountsKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return []
        }
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.readFailed(status)
        }
        
        return try JSONDecoder().decode([LLMAccount].self, from: data)
    }
    
    private func writeAccountsSync(_ accounts: [LLMAccount]) throws {
        let data = try JSONEncoder().encode(accounts)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountsKey
        ]
        
        let attrs: [String: Any] = [
            kSecValueData as String: data
        ]
        
        var status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            status = SecItemAdd(newItem as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status)
        }
    }
    
    // MARK: - Generic Password Access (for external keychain items)
    
    /// Read a generic password from any keychain service
    public static func readGenericPassword(service: String, account: String? = nil) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
}

public enum KeychainError: Error {
    case readFailed(OSStatus)
    case writeFailed(OSStatus)
}
