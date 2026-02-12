import Foundation

/// Period for usage metrics
public struct UsagePeriod: Codable, Sendable {
    public let label: String           // "Session", "Weekly", "Monthly"
    public let resetsAt: Date?
    public let durationMs: Int?
    
    public init(label: String, resetsAt: Date? = nil, durationMs: Int? = nil) {
        self.label = label
        self.resetsAt = resetsAt
        self.durationMs = durationMs
    }
}

/// Format for displaying usage values
public enum UsageFormat: Codable, Sendable {
    case percent
    case dollars(used: Double, limit: Double)
    case count(used: Int, limit: Int, suffix: String)
}

/// A single usage metric line
public struct UsageMetric: Codable, Sendable {
    public let label: String
    public let usedPercent: Double     // 0-100
    public let format: UsageFormat
    public let period: UsagePeriod?
    
    public init(
        label: String,
        usedPercent: Double,
        format: UsageFormat,
        period: UsagePeriod? = nil
    ) {
        self.label = label
        self.usedPercent = min(100, max(0, usedPercent))
        self.format = format
        self.period = period
    }
}

/// Plan information
public struct PlanInfo: Codable, Sendable {
    public let name: String?
    public let tier: String?
    
    public init(name: String? = nil, tier: String? = nil) {
        self.name = name
        self.tier = tier
    }
}

/// Complete usage data for an account
public struct UsageData: Codable, Sendable {
    public let account: LLMAccount
    public let plan: PlanInfo?
    public let metrics: [UsageMetric]
    public let settingURL: URL?
    public let fetchedAt: Date
    
    public init(
        account: LLMAccount,
        plan: PlanInfo? = nil,
        metrics: [UsageMetric],
        settingURL: URL? = nil,
        fetchedAt: Date = Date()
    ) {
        self.account = account
        self.plan = plan
        self.metrics = metrics
        self.settingURL = settingURL
        self.fetchedAt = fetchedAt
    }
}
