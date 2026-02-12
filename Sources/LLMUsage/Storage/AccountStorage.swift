import Foundation

/// Protocol for persisting and retrieving LLM accounts
public protocol AccountStorage: Sendable {
    func loadAccounts() async throws -> [LLMAccount]
    func saveAccounts(_ accounts: [LLMAccount]) async throws
    func loadAccount(id: UUID) async throws -> LLMAccount?
    func saveAccount(_ account: LLMAccount) async throws
    func deleteAccount(id: UUID) async throws
}
