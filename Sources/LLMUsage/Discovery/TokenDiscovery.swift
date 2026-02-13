import Foundation

public struct DiscoveryResult: Sendable {
    public let service: LLMService
    public let tokens: [TokenInfo]
    public let source: String  // "file", "keychain", "sqlite", etc.
    public let label: String?
    
    public init(service: LLMService, tokens: [TokenInfo], source: String, label: String? = nil) {
        self.service = service
        self.tokens = tokens
        self.source = source
        self.label = label
    }
}

/// Protocol for service-specific token discovery
public protocol TokenDiscoverer: Sendable {
    var service: LLMService { get }
    func discover() async throws -> [DiscoveryResult]
}

/// Coordinator for running all token discoveries
public actor TokenDiscoveryCoordinator {
    private var discoverers: [TokenDiscoverer] = []
    
    public init() {}
    
    public func register(_ discoverer: TokenDiscoverer) {
        discoverers.append(discoverer)
    }
    
    public func registerDefaults() {
        discoverers = [
            ClaudeDiscovery(),
            CopilotDiscovery(),
            CursorDiscovery(),
            WindsurfDiscovery(),
            CodexDiscovery(),
            AntigravityDiscovery()
        ]
    }
    
    /// Discover tokens for all registered services
    public func discoverAll() async -> [DiscoveryResult] {
        await withTaskGroup(of: [DiscoveryResult].self) { group in
            for discoverer in discoverers {
                group.addTask {
                    do {
                        return try await withThrowingTaskGroup(of: [DiscoveryResult].self) { innerGroup in
                            innerGroup.addTask {
                                try await discoverer.discover()
                            }
                            innerGroup.addTask {
                                try await Task.sleep(for: .seconds(20))
                                throw DiscoveryError.timeout
                            }
                            let result = try await innerGroup.next()!
                            innerGroup.cancelAll()
                            return result
                        }
                    } catch {
                        return []
                    }
                }
            }

            var results: [DiscoveryResult] = []
            for await result in group {
                results.append(contentsOf: result)
            }
            return results
        }
    }
    
    enum DiscoveryError: Error {
        case timeout
    }
    
    /// Discover tokens for a specific service
    public func discover(service: LLMService) async -> [DiscoveryResult] {
        guard let discoverer = discoverers.first(where: { $0.service == service }) else {
            return []
        }
        return (try? await discoverer.discover()) ?? []
    }
}
