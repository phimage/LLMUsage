import Foundation

/// Discovers Copilot tokens from gh CLI keychain
public struct CopilotDiscovery: TokenDiscoverer {
    public let service = LLMService.copilot
    
    private let ghKeychainService = "gh:github.com"
    
    public init() {}
    
    public func discover() async throws -> DiscoveryResult? {
        guard var token = KeychainStorage.readGenericPassword(service: ghKeychainService) else {
            return nil
        }
        
        // Handle go-keyring base64 encoding
        let prefix = "go-keyring-base64:"
        if token.hasPrefix(prefix) {
            let encoded = String(token.dropFirst(prefix.count))
            guard let data = Data(base64Encoded: encoded),
                  let decoded = String(data: data, encoding: .utf8) else {
                return nil
            }
            token = decoded
        }
        
        guard !token.isEmpty else { return nil }
        
        let tokenInfo = TokenInfo(
            accessToken: token,
            refreshToken: nil,
            expiresAt: nil,
            source: .discovered
        )
        
        let label = await CopilotDiscovery.fetchUsername(token: token)
        
        return DiscoveryResult(service: .copilot, tokens: [tokenInfo], source: "gh-cli", label: label)
    }
    
    public static func fetchUsername(token: String) async -> String? {
        // Run fetch with 2s timeout
        do {
            return try await withThrowingTaskGroup(of: String?.self) { group in
                group.addTask {
                    guard let url = URL(string: "https://api.github.com/user") else { return nil }
                    var request = URLRequest(url: url)
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.setValue("LLMUsage", forHTTPHeaderField: "User-Agent")
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        return nil
                    }
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let login = json["login"] as? String {
                        return login
                    }
                    return nil
                }
                
                group.addTask {
                    try await Task.sleep(for: .seconds(5))
                    throw URLError(.timedOut)
                }
                
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch {
            return nil
        }
    }
}
