import Foundation

/// Protocol for fetching usage data from LLM services
public protocol UsageClient: Sendable {
    var service: LLMService { get }
    func fetchUsage(account: LLMAccount) async throws -> UsageData
}

/// Errors from usage API calls
public enum UsageClientError: Error {
    case noToken
    case tokenExpired
    case unauthorized
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
}
