import Testing
@testable import LLMUsage

@Test func testLLMAccountCreation() async throws {
    let token = TokenInfo(accessToken: "test-token", source: .manual)
    var account = LLMAccount(service: .claude, label: "Test", tokens: [token])
    
    #expect(account.service == .claude)
    #expect(account.label == "Test")
    #expect(account.tokens.count == 1)
    #expect(account.isActive == true)
    #expect(account.primaryToken?.accessToken == "test-token")
    
    // Test upsert
    let newToken = TokenInfo(accessToken: "new-token", source: .discovered)
    account.upsertToken(newToken)
    #expect(account.tokens.count == 2)
}

@Test func testTokenExpiry() async throws {
    let expired = TokenInfo(
        accessToken: "expired",
        expiresAt: Date().addingTimeInterval(-60),
        source: .oauth
    )
    #expect(expired.isExpired == true)
    #expect(expired.needsRefresh == true)
    
    let valid = TokenInfo(
        accessToken: "valid",
        expiresAt: Date().addingTimeInterval(3600),
        source: .oauth
    )
    #expect(valid.isExpired == false)
    #expect(valid.needsRefresh == false)
    
    let nearExpiry = TokenInfo(
        accessToken: "near",
        expiresAt: Date().addingTimeInterval(3 * 60), // 3 minutes
        source: .oauth
    )
    #expect(nearExpiry.isExpired == false)
    #expect(nearExpiry.needsRefresh == true) // within 5 minute buffer
}

@Test func testLLMServiceDisplayName() async throws {
    #expect(LLMService.claude.displayName == "Claude")
    #expect(LLMService.copilot.displayName == "GitHub Copilot")
    #expect(LLMService.cursor.displayName == "Cursor")
    #expect(LLMService.codex.displayName == "Codex")
    #expect(LLMService.antigravity.displayName == "Antigravity")
}
