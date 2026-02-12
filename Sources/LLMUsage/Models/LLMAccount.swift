import Foundation

/// An LLM service account with support for multiple tokens
public struct LLMAccount: Identifiable, Codable, Sendable {
    public let id: UUID
    public var service: LLMService
    public var label: String           // "Personal", "Work", etc.
    public var tokens: [TokenInfo]
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        service: LLMService,
        label: String,
        tokens: [TokenInfo] = [],
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.service = service
        self.label = label
        self.tokens = tokens
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Primary token for this account (first valid one)
    public var primaryToken: TokenInfo? {
        tokens.first { !$0.isExpired }
    }
    
    /// Add or update a token
    public mutating func upsertToken(_ token: TokenInfo) {
        if let idx = tokens.firstIndex(where: { $0.accessToken == token.accessToken }) {
            tokens[idx] = token
        } else {
            tokens.append(token)
        }
        updatedAt = Date()
    }
}
