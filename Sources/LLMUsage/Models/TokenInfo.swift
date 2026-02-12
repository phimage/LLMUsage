import Foundation

/// How a token was obtained
public enum TokenSource: String, Codable, Sendable {
    case discovered  // auto-discovered from app credentials
    case manual      // user-entered API key
    case oauth       // obtained via OAuth flow
}

/// Token information for authentication
public struct TokenInfo: Codable, Sendable {
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?
    public var source: TokenSource
    
    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        source: TokenSource
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.source = source
    }
    
    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }
    
    public var needsRefresh: Bool {
        guard let expiresAt else { return false }
        // Refresh 5 minutes before expiry
        return Date().addingTimeInterval(5 * 60) >= expiresAt
    }
}
