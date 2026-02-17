import Foundation

/// Discovers Codex tokens from auth file
public struct CodexDiscovery: TokenDiscoverer {
    public let service = LLMService.codex
    
    private let configPaths = ["~/.config/codex", "~/.codex"]
    private let authFile = "auth.json"
    
    public init() {}

    // MARK: - TokenDiscoverer
    
    public func discover() async throws -> DiscoveryResult? {
        // Check CODEX_HOME first
        if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] {
            let path = (codexHome as NSString).appendingPathComponent(authFile)
            if let result = try? loadAuth(from: path) {
                return result
            }
        }
        
        // Fall back to config paths
        for basePath in configPaths {
            let expanded = (basePath as NSString).expandingTildeInPath
            let path = (expanded as NSString).appendingPathComponent(authFile)
            if let result = try? loadAuth(from: path) {
                return result
            }
        }
        
        return nil
    }
    
    private func loadAuth(from path: String) throws -> DiscoveryResult? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String, !accessToken.isEmpty else {
            return nil
        }
        
        let refreshToken = tokens["refresh_token"] as? String
        
        let token = TokenInfo(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: nil,  // Codex uses age-based refresh (8 days)
            source: .discovered
        )
        
        return DiscoveryResult(service: .codex, tokens: [token], source: "file")
    }
}
