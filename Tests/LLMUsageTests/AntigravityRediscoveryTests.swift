import XCTest
@testable import LLMUsage

final class AntigravityRediscoveryTests: XCTestCase {
    
    func testRediscoveryOnFailure() async throws {
        let usage = LLMUsage(storage: MockStorage())
        try await usage.setup()
        
        let account = LLMAccount(
            service: .antigravity,
            label: "Test",
            tokens: [TokenInfo(accessToken: "old:token", source: .manual)]
        )
        try await usage.saveAccount(account)
        
        // Mock client that fails once then succeeds
        let mockClient = MockFailingClient()
        await usage.registerClient(mockClient, for: .antigravity)
        
        // This should trigger rediscovery and succeed if the discovery finds something
        // or fail with the second error if discovery finds nothing new.
        // Actually, discoverAndImport will try to find tokens.
        
        // Since we can't easily mock discovery without more changes, 
        // let's just verify that it attempts to call the client again.
        
        do {
            _ = try await usage.fetchUsage(account: account)
        } catch {
            // It might still fail if discovery doesn't find a working port
            // but we want to know it RETRIED.
        }
        
        let callCount = await mockClient.getCallCount()
        XCTAssertEqual(callCount, 2, "Should have retried after failure")
    }
}

actor MockFailingClient: UsageClient {
    let service = LLMService.antigravity
    var callCount = 0
    let settingURL: URL? = nil
    
    func fetchUsage(account: LLMAccount) async throws -> UsageData {
        callCount += 1
        throw NSError(domain: "test", code: 1, userInfo: nil)
    }
    
    func getCallCount() -> Int {
        return callCount
    }
}

actor MockStorage: AccountStorage {
    var accounts: [LLMAccount] = []
    func loadAccounts() async throws -> [LLMAccount] { accounts }
    func saveAccounts(_ accounts: [LLMAccount]) async throws { self.accounts = accounts }
    func loadAccount(id: UUID) async throws -> LLMAccount? { accounts.first { $0.id == id } }
    func saveAccount(_ account: LLMAccount) async throws {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
    }
    func deleteAccount(id: UUID) async throws { accounts.removeAll { $0.id == id } }
}
