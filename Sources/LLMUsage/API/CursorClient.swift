import Foundation

/// Cursor usage API client (Connect protocol)
public struct CursorClient: UsageClient {
    public let service = LLMService.cursor
    
    private let baseURL = "https://api2.cursor.sh"
    private let usageURL = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!
    private let planURL = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetPlanInfo")!
    public var settingURL: URL? = nil
    
    public init() {}
    
    public func fetchUsage(account: LLMAccount) async throws -> UsageData {
        guard let token = account.primaryToken else {
            throw UsageClientError.noToken
        }
        
        let usageData = try await connectPost(url: usageURL, token: token.accessToken)
        
        guard let enabled = usageData["enabled"] as? Bool, enabled,
              let planUsage = usageData["planUsage"] as? [String: Any] else {
            throw UsageClientError.invalidResponse
        }
        
        // Fetch plan info (optional)
        let planInfo: PlanInfo?
        if let planData = try? await connectPost(url: planURL, token: token.accessToken),
           let pi = planData["planInfo"] as? [String: Any],
           let planName = pi["planName"] as? String {
            planInfo = PlanInfo(name: planName)
        } else {
            planInfo = nil
        }
        
        return parseUsage(usageData: usageData, planUsage: planUsage, plan: planInfo, account: account)
    }
    
    private func connectPost(url: URL, token: String) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.httpBody = "{}".data(using: .utf8)
        
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
        
        return json
    }
    
    private func parseUsage(
        usageData: [String: Any],
        planUsage: [String: Any],
        plan: PlanInfo?,
        account: LLMAccount
    ) -> UsageData {
        var metrics: [UsageMetric] = []
        
        let billingEnd = usageData["billingCycleEnd"] as? String
        let billingStart = usageData["billingCycleStart"] as? String
        let resetsAt = billingEnd.flatMap { parseTimestamp($0) }
        
        var periodMs = 30 * 24 * 60 * 60 * 1000  // 30 days default
        if let start = billingStart.flatMap({ parseTimestamp($0) }),
           let end = resetsAt,
           end > start {
            periodMs = Int((end.timeIntervalSince(start)) * 1000)
        }
        
        // Plan usage (dollars)
        if let limit = planUsage["limit"] as? Double, limit > 0 {
            let totalSpend = planUsage["totalSpend"] as? Double
            let remaining = planUsage["remaining"] as? Double
            let used = totalSpend ?? (limit - (remaining ?? 0))
            let usedPercent = (used / limit) * 100
            
            metrics.append(UsageMetric(
                label: "Plan usage",
                usedPercent: usedPercent,
                format: .dollars(used: used, limit: limit),
                period: UsagePeriod(label: "Billing cycle", resetsAt: resetsAt, durationMs: periodMs)
            ))
        }
        
        return UsageData(account: account, plan: plan, metrics: metrics, settingURL: settingURL)
    }
    
    private func parseTimestamp(_ value: String) -> Date? {
        // Cursor returns timestamps as milliseconds string
        if let ms = Double(value) {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        return nil
    }
}
