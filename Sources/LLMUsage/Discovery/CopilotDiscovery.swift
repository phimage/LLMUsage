import Foundation

/// Discovers Copilot tokens from gh CLI keychain
public struct CopilotDiscovery: TokenDiscoverer {
    public let service = LLMService.copilot
    
    private let ghKeychainService = "gh:github.com"
    
    public init() {}
    
    public func discover() async throws -> [DiscoveryResult] {
        let entries = KeychainStorage.readAllGenericPasswords(service: ghKeychainService)
        guard !entries.isEmpty else { return [] }

        var results: [DiscoveryResult] = []
        let prefix = "go-keyring-base64:"

        for entry in entries {
            var token = entry

            // Handle go-keyring base64 encoding
            if token.hasPrefix(prefix) {
                let encoded = String(token.dropFirst(prefix.count))
                guard let data = Data(base64Encoded: encoded),
                      let decoded = String(data: data, encoding: .utf8) else {
                    continue
                }
                token = decoded
            }

            guard !token.isEmpty else { continue }

            let tokenInfo = TokenInfo(
                accessToken: token,
                refreshToken: nil,
                expiresAt: nil,
                source: .discovered
            )

            let label = await CopilotDiscovery.fetchUsername(token: token)

            results.append(DiscoveryResult(service: .copilot, tokens: [tokenInfo], source: "gh-cli", label: label))
        }

        return results
    }
    
    public static func fetchUsername(token: String) async -> String? {
        // Run fetch with 10s timeout
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
                    
					if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let value = json["login"] {
						if let login = value as? String {
							return login
						}
						return String(describing: value) // NSTaggedPointerString?
                    }
                    return nil
                }
                
                group.addTask {
                    try await Task.sleep(for: .seconds(2))
                    throw URLError(.timedOut)
                }
                
                let result = try await group.next()
                //group.cancelAll()
                return result!
            }
        } catch {
			print("\(error)")
            return nil
        }
    }
}
