import Foundation

/// GitHub Copilot usage API client
public struct CopilotClient: UsageClient {
    public let service = LLMService.copilot
    
    private let usageURL = URL(string: "https://api.github.com/copilot_internal/user")!
    private let settingURL: URL = URL(string: "https://github.com/settings/copilot/features")!
    
    public init() {}
    
    public func fetchUsage(account: LLMAccount) async throws -> UsageData {
        guard let token = account.primaryToken else {
            throw UsageClientError.noToken
        }
        
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("token \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("vscode/1.96.2", forHTTPHeaderField: "Editor-Version")
        request.setValue("copilot-chat/0.26.7", forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue("GitHubCopilotChat/0.26.7", forHTTPHeaderField: "User-Agent")
        request.setValue("2025-04-01", forHTTPHeaderField: "X-Github-Api-Version")
        
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
        
        return parseUsage(json: json, account: account)
    }
    
    private func parseUsage(json: [String: Any], account: LLMAccount) -> UsageData {
        var metrics: [UsageMetric] = []
        
        let plan = (json["copilot_plan"] as? String).map { PlanInfo(name: $0) }
        let resetDate = parseDate(json["quota_reset_date"])
        let periodMs = 30 * 24 * 60 * 60 * 1000  // 30 days
        
        // Paid tier: quota_snapshots
        if let snapshots = json["quota_snapshots"] as? [String: Any] {
            if let premium = snapshots["premium_interactions"] as? [String: Any],
               let remaining = premium["percent_remaining"] as? Double {
                let usedPercent = 100 - remaining
                metrics.append(UsageMetric(
                    label: "Premium",
                    usedPercent: usedPercent,
                    format: .percent,
                    period: UsagePeriod(label: "Monthly", resetsAt: resetDate, durationMs: periodMs)
                ))
            }
            
            if let chat = snapshots["chat"] as? [String: Any],
               let remaining = chat["percent_remaining"] as? Double {
                let usedPercent = 100 - remaining
                metrics.append(UsageMetric(
                    label: "Chat",
                    usedPercent: usedPercent,
                    format: .percent,
                    period: UsagePeriod(label: "Monthly", resetsAt: resetDate, durationMs: periodMs)
                ))
            }
        }
        
        // Free tier: limited_user_quotas
        if let limitedQuotas = json["limited_user_quotas"] as? [String: Any],
           let monthlyQuotas = json["monthly_quotas"] as? [String: Any] {
            let freeResetDate = parseDate(json["limited_user_reset_date"])
            
            if let chatRemaining = limitedQuotas["chat"] as? Int,
               let chatTotal = monthlyQuotas["chat"] as? Int, chatTotal > 0 {
                let used = chatTotal - chatRemaining
                let usedPercent = Double(used) / Double(chatTotal) * 100
                metrics.append(UsageMetric(
                    label: "Chat",
                    usedPercent: usedPercent,
                    format: .count(used: used, limit: chatTotal, suffix: "messages"),
                    period: UsagePeriod(label: "Monthly", resetsAt: freeResetDate, durationMs: periodMs)
                ))
            }
            
            if let compRemaining = limitedQuotas["completions"] as? Int,
               let compTotal = monthlyQuotas["completions"] as? Int, compTotal > 0 {
                let used = compTotal - compRemaining
                let usedPercent = Double(used) / Double(compTotal) * 100
                metrics.append(UsageMetric(
                    label: "Completions",
                    usedPercent: usedPercent,
                    format: .count(used: used, limit: compTotal, suffix: "completions"),
                    period: UsagePeriod(label: "Monthly", resetsAt: freeResetDate, durationMs: periodMs)
                ))
            }
        }
        
        return UsageData(account: account, plan: plan, metrics: metrics)
    }
    
    private func parseDate(_ value: Any?) -> Date? {
        guard let str = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: str)
    }
}
