import Foundation

/// Discovers Claude tokens from credential file or keychain
public struct ClaudeDiscovery: TokenDiscoverer {
    public let service = LLMService.claude
    
    private let credentialPath = "~/.claude/.credentials.json"
    private let keychainService = "Claude Code-credentials"
    
    public init() {}
    
    public func discover() async throws -> DiscoveryResult? {
        // Try credential file first
        if let result = try? discoverFromFile() {
            return result
        }
        
        // Fallback to keychain
        return discoverFromKeychain()
    }
    
    private func discoverFromFile() throws -> DiscoveryResult? {
        let path = (credentialPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String, !accessToken.isEmpty else {
            return nil
        }
        
        let refreshToken = oauth["refreshToken"] as? String
        let expiresAt: Date? = {
            guard let ms = oauth["expiresAt"] as? Double else { return nil }
            return Date(timeIntervalSince1970: ms / 1000)
        }()
        
        let token = TokenInfo(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            source: .discovered
        )
        
        return DiscoveryResult(service: .claude, tokens: [token], source: "file")
    }
    
    private func discoverFromKeychain() -> DiscoveryResult? {
        guard let raw = KeychainStorage.readGenericPassword(service: keychainService) else {
            return nil
        }
        
        // May be hex-encoded UTF-8
        let jsonString = decodeHexIfNeeded(raw)
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String, !accessToken.isEmpty else {
            return nil
        }
        
        let refreshToken = oauth["refreshToken"] as? String
        let expiresAt: Date? = {
            guard let ms = oauth["expiresAt"] as? Double else { return nil }
            return Date(timeIntervalSince1970: ms / 1000)
        }()
        
        let token = TokenInfo(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            source: .discovered
        )
        
        return DiscoveryResult(service: .claude, tokens: [token], source: "keychain")
    }
    
    /// Decode hex-encoded UTF-8 (macOS keychain sometimes returns this)
    private func decodeHexIfNeeded(_ input: String) -> String {
        var hex = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = String(hex.dropFirst(2))
        }
        
        guard hex.count % 2 == 0,
              hex.allSatisfy({ $0.isHexDigit }) else {
            return input
        }
        
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }
        
        return String(decoding: bytes, as: UTF8.self)
    }
}
