import Testing
@testable import LLMUsage
import Foundation

@Test func testClaudeDiscoveryParseCredentials() async throws {
    // Test credential JSON parsing logic
    
    // Simulate what hex decode would produce
    let jsonString = """
    {"claudeAiOauth":{"accessToken":"test-token-123","refreshToken":"refresh-456","expiresAt":1735689600000}}
    """
    
    // Verify JSON parsing logic by checking the model
    guard let data = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let oauth = json["claudeAiOauth"] as? [String: Any],
          let accessToken = oauth["accessToken"] as? String else {
        Issue.record("Failed to parse test JSON")
        return
    }
    
    #expect(accessToken == "test-token-123")
    #expect(oauth["refreshToken"] as? String == "refresh-456")
    
    // Test expiry parsing
    if let expiresAtMs = oauth["expiresAt"] as? Double {
        let date = Date(timeIntervalSince1970: expiresAtMs / 1000)
        #expect(date > Date(timeIntervalSince1970: 0))
    }
}

@Test func testCopilotDiscoveryBase64Decode() async throws {
    // Test go-keyring base64 decoding
    let prefix = "go-keyring-base64:"
    let originalToken = "gho_testtoken123456"
    let encoded = prefix + Data(originalToken.utf8).base64EncodedString()
    
    // Simulate decoding logic
    var token = encoded
    if token.hasPrefix(prefix) {
        let encodedPart = String(token.dropFirst(prefix.count))
        if let data = Data(base64Encoded: encodedPart),
           let decoded = String(data: data, encoding: .utf8) {
            token = decoded
        }
    }
    
    #expect(token == originalToken)
}

@Test func testCursorDiscoveryJWTDecode() async throws {
    // Test JWT expiration parsing
    // JWT payload: {"exp": 1735689600} (encoded as base64)
    let payload = """
    {"exp":1735689600,"sub":"user123"}
    """
    let base64Payload = Data(payload.utf8).base64EncodedString()
        .replacingOccurrences(of: "=", with: "")
    
    // Simulate JWT: header.payload.signature
    let fakeJWT = "eyJhbGciOiJSUzI1NiJ9.\(base64Payload).fakesig"
    
    // Parse expiration
    let parts = fakeJWT.split(separator: ".")
    #expect(parts.count >= 2)
    
    var base64 = String(parts[1])
    while base64.count % 4 != 0 {
        base64.append("=")
    }
    
    if let data = Data(base64Encoded: base64),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let exp = json["exp"] as? Double {
        let date = Date(timeIntervalSince1970: exp)
        #expect(date > Date(timeIntervalSince1970: 0))
    } else {
        Issue.record("Failed to decode JWT expiration")
    }
}

@Test func testWindsurfDiscoveryApiKeyParsing() async throws {
    // Test parsing API key from JSON
    let authStatus = """
    {"apiKey":"ws-api-key-test-123","userId":"user456"}
    """
    
    guard let data = authStatus.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let apiKey = json["apiKey"] as? String else {
        Issue.record("Failed to parse auth status")
        return
    }
    
    #expect(apiKey == "ws-api-key-test-123")
}

@Test func testDiscoveryResultCreation() async throws {
    let token = TokenInfo(accessToken: "test", source: .discovered)
    let result = DiscoveryResult(service: .claude, tokens: [token], source: "file")
    
    #expect(result.service == .claude)
    #expect(result.tokens.count == 1)
    #expect(result.source == "file")
}
