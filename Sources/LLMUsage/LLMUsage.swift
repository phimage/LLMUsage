import Foundation

/// Main LLMUsage orchestrator for LLM account management
public actor LLMUsage {
    private let storage: AccountStorage
    private let discovery: TokenDiscoveryCoordinator
    private var accounts: [LLMAccount] = []
    private var clients: [LLMService: any UsageClient] = [:]
    
    public init(storage: AccountStorage? = nil) {
        self.storage = storage ?? KeychainStorage()
        self.discovery = TokenDiscoveryCoordinator()
    }
    
    /// Initialize LLMUsage with default settings
    public func setup() async throws {
        await discovery.registerDefaults()
        accounts = try await storage.loadAccounts()
        
        // Register default clients
        clients[.claude] = ClaudeClient()
        clients[.copilot] = CopilotClient()
        clients[.cursor] = CursorClient()
        clients[.codex] = CodexClient()
        clients[.antigravity] = AntigravityClient()
    }
    
    // MARK: - Account Management
    
    /// Get all accounts
    public func getAccounts() -> [LLMAccount] {
        accounts
    }
    
    /// Get accounts for a specific service
    public func getAccounts(for service: LLMService) -> [LLMAccount] {
        accounts.filter { $0.service == service }
    }
    
    /// Add or update an account
    public func saveAccount(_ account: LLMAccount) async throws {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
        try await storage.saveAccounts(accounts)
    }
    
    /// Delete an account
    public func deleteAccount(id: UUID) async throws {
        accounts.removeAll { $0.id == id }
        try await storage.saveAccounts(accounts)
    }

    /// Save a new account ordering
    public func saveAccountsInOrder(_ ordered: [LLMAccount]) async throws {
        accounts = ordered
        try await storage.saveAccounts(accounts)
    }
    
    // MARK: - Token Discovery
    
    /// Discover tokens for all services and create/update accounts
    public func discoverAndImport(service: LLMService? = nil) async throws -> [LLMAccount] {
        let results: [DiscoveryResult]
        if let service {
            results = await discovery.discover(service: service)
        } else {
            results = await discovery.discoverAll()
        }
        var imported: [LLMAccount] = []
        
        for result in results {
            // Match by (service + label) first, then fall back to (service only)
            let existing: LLMAccount?
            if let label = result.label {
                existing = accounts.first(where: { $0.service == result.service && $0.label == label })
                    ?? accounts.first(where: { $0.service == result.service })
            } else {
                existing = accounts.first(where: { $0.service == result.service })
            }

            if var match = existing {
                for token in result.tokens {
                    match.upsertToken(token)
                }
                // Update label if discovery provides one and current is generic
                if let label = result.label, match.label == "Default" {
                    match.label = label
                }
                try await saveAccount(match)
                imported.append(match)
            } else {
                let account = LLMAccount(
                    service: result.service,
                    label: result.label ?? "Default",
                    tokens: result.tokens,
                    isActive: true
                )
                try await saveAccount(account)
                imported.append(account)
            }
        }
        
        return imported
    }
    
    /// Discover tokens for a specific service
    public func discover(service: LLMService) async -> [DiscoveryResult] {
        await discovery.discover(service: service)
    }
    
    // MARK: - Usage Fetching
    
    /// Fetch usage for a specific account
    public func fetchUsage(account: LLMAccount) async throws -> UsageData {
        guard let client = clients[account.service] else {
            throw LLMUsageError.noClientForService(account.service)
        }
        
        do {
            return try await client.fetchUsage(account: account)
        } catch {
            if account.service == .antigravity {
                // Try once to rediscover
                _ = try? await discoverAndImport(service: .antigravity)
                // Get the updated account
                if let updatedAccount = accounts.first(where: { $0.id == account.id }) {
                    return try await client.fetchUsage(account: updatedAccount)
                }
            }
            throw error
        }
    }
    
    /// Fetch usage for all active accounts
    public func fetchAllUsage() async -> [Result<UsageData, Error>] {
        let activeAccounts = accounts.filter { $0.isActive }
        
        return await withTaskGroup(of: Result<UsageData, Error>.self) { group in
            for account in activeAccounts {
                group.addTask {
                    do {
                        let usage = try await self.fetchUsage(account: account)
                        return .success(usage)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            var results: [Result<UsageData, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    // MARK: - Testing Support
    
    internal func registerClient(_ client: any UsageClient, for service: LLMService) {
        clients[service] = client
    }
}

public enum LLMUsageError: Error {
    case noClientForService(LLMService)
    case accountNotFound
}
