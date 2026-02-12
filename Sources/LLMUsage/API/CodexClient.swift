import Foundation

/// Codex (OpenAI) usage API client
public struct CodexClient: UsageClient {
    public let service = LLMService.codex
    
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    public var settingURL: URL? = nil

    public init() {}
    
    public func fetchUsage(account: LLMAccount) async throws -> UsageData {
        guard let token = account.primaryToken else {
            throw UsageClientError.noToken
        }
        
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LLMUsage", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageClientError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw UsageClientError.tokenExpired
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UsageClientError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageClientError.invalidResponse
        }
        
        return parseUsage(json: json, headers: httpResponse.allHeaderFields, account: account)
    }
    
    private func parseUsage(json: [String: Any], headers: [AnyHashable: Any], account: LLMAccount) -> UsageData {
        var metrics: [UsageMetric] = []
        let nowSec = Int(Date().timeIntervalSince1970)
        
        let sessionPeriodMs = 5 * 60 * 60 * 1000
        let weeklyPeriodMs = 7 * 24 * 60 * 60 * 1000
        
        // Try headers first
        if let primaryPercent = parseHeaderPercent(headers, key: "x-codex-primary-used-percent") {
            let resetsAt = getResetTime(json: json, window: "primary_window", nowSec: nowSec)
            metrics.append(UsageMetric(
                label: "Session",
                usedPercent: primaryPercent,
                format: .percent,
                period: UsagePeriod(label: "5 hours", resetsAt: resetsAt, durationMs: sessionPeriodMs)
            ))
        }
        
        if let secondaryPercent = parseHeaderPercent(headers, key: "x-codex-secondary-used-percent") {
            let resetsAt = getResetTime(json: json, window: "secondary_window", nowSec: nowSec)
            metrics.append(UsageMetric(
                label: "Weekly",
                usedPercent: secondaryPercent,
                format: .percent,
                period: UsagePeriod(label: "7 days", resetsAt: resetsAt, durationMs: weeklyPeriodMs)
            ))
        }
        
        // Fall back to JSON body
        if metrics.isEmpty, let rateLimit = json["rate_limit"] as? [String: Any] {
            if let primary = rateLimit["primary_window"] as? [String: Any],
               let usedPercent = primary["used_percent"] as? Double {
                let resetsAt = getResetTime(json: json, window: "primary_window", nowSec: nowSec)
                metrics.append(UsageMetric(
                    label: "Session",
                    usedPercent: usedPercent,
                    format: .percent,
                    period: UsagePeriod(label: "5 hours", resetsAt: resetsAt, durationMs: sessionPeriodMs)
                ))
            }
            if let secondary = rateLimit["secondary_window"] as? [String: Any],
               let usedPercent = secondary["used_percent"] as? Double {
                let resetsAt = getResetTime(json: json, window: "secondary_window", nowSec: nowSec)
                metrics.append(UsageMetric(
                    label: "Weekly",
                    usedPercent: usedPercent,
                    format: .percent,
                    period: UsagePeriod(label: "7 days", resetsAt: resetsAt, durationMs: weeklyPeriodMs)
                ))
            }
        }
        
        // Credits balance
        if let creditsBalance = parseHeaderDouble(headers, key: "x-codex-credits-balance") {
            let remaining = Int(creditsBalance)
            let limit = 1000
            let used = max(0, min(limit, limit - remaining))
            let usedPercent = Double(used) / Double(limit) * 100
            metrics.append(UsageMetric(
                label: "Credits",
                usedPercent: usedPercent,
                format: .count(used: used, limit: limit, suffix: "credits"),
                period: nil
            ))
        }
        
        let plan = (json["plan_type"] as? String).map { PlanInfo(name: $0) }
        
        return UsageData(account: account, plan: plan, metrics: metrics, settingURL: settingURL)
    }
    
    private func parseHeaderPercent(_ headers: [AnyHashable: Any], key: String) -> Double? {
        guard let value = headers[key] as? String,
              let num = Double(value) else { return nil }
        return num
    }
    
    private func parseHeaderDouble(_ headers: [AnyHashable: Any], key: String) -> Double? {
        guard let value = headers[key] as? String,
              let num = Double(value) else { return nil }
        return num
    }
    
    private func getResetTime(json: [String: Any], window: String, nowSec: Int) -> Date? {
        guard let rateLimit = json["rate_limit"] as? [String: Any],
              let windowData = rateLimit[window] as? [String: Any] else {
            return nil
        }
        
        if let resetAt = windowData["reset_at"] as? Int {
            return Date(timeIntervalSince1970: Double(resetAt))
        }
        if let resetAfter = windowData["reset_after_seconds"] as? Int {
            return Date(timeIntervalSince1970: Double(nowSec + resetAfter))
        }
        return nil
    }
}
