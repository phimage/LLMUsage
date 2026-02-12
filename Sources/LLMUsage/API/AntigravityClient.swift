import Foundation

/// Antigravity usage client (local language server RPC)
public struct AntigravityClient: UsageClient {
    public let service = LLMService.antigravity
    
    private let lsService = "exa.language_server_pb.LanguageServerService"
    public var settingURL: URL? = nil
    
    public init() {}
    
    public func fetchUsage(account: LLMAccount) async throws -> UsageData {
        var lastError: Error = UsageClientError.noToken
        
        // Try all tokens (ports) until one works
        for token in account.tokens {
            do {
                // Token format: "port:csrf"
                let parts = token.accessToken.split(separator: ":")
                guard parts.count == 2,
                      let port = Int(parts[0]) else {
                    continue
                }
                let csrf = String(parts[1])
                
                // Try to get status
                // We know from investigation that the random ports support HTTP and/or HTTPS
                // And the service is exa.language_server_pb.LanguageServerService
                
                // Try HTTP first as it's faster/simpler if available (lsof showed TCP LISTEN)
                // If that fails, try HTTPS.
                
                if let result = try await probe(port: port, csrf: csrf) {
                    return parseUsage(data: result, account: account)
                }
                
            } catch {
                lastError = error
                // print("DEBUG: Token \(token.accessToken)... failed: \(error)")
            }
        }
        
        throw lastError
    }
    
    private func probe(port: Int, csrf: String) async throws -> [String: Any]? {
        // Try HTTP
        if let data = try? await callLs(port: port, scheme: "http", csrf: csrf, method: "GetUserStatus") {
            if data["userStatus"] != nil { return data }
        }
        
        // Try HTTPS
        if let data = try? await callLs(port: port, scheme: "https", csrf: csrf, method: "GetUserStatus") {
             if data["userStatus"] != nil { return data }
        }
       
        return nil
    }
    
    private func callLs(port: Int, scheme: String, csrf: String, method: String) async throws -> [String: Any]? {
        let url = URL(string: "\(scheme)://127.0.0.1:\(port)/\(lsService)/\(method)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(csrf, forHTTPHeaderField: "x-codeium-csrf-token")
        
        let body: [String: Any] = [
            "metadata": [
                "ideName": "antigravity",
                "extensionName": "antigravity",
                "ideVersion": "unknown",
                "locale": "en"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Create session that ignores TLS for localhost (self-signed certs)
        let config = URLSessionConfiguration.ephemeral
        let delegate = InsecureDelegate()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200..<300).contains(httpResponse.statusCode) {
                    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
            }
            return nil
        } catch {
            return nil
        }
    }
    
    private func parseUsage(data: [String: Any], account: LLMAccount) -> UsageData {
        var metrics: [UsageMetric] = []
        var plan: PlanInfo?
        
        var configs: [[String: Any]] = []
        
        if let userStatus = data["userStatus"] as? [String: Any] {
            // Plan info available in userStatus
            if let planStatus = userStatus["planStatus"] as? [String: Any],
               let planInfo = planStatus["planInfo"] as? [String: Any],
               let planName = planInfo["planName"] as? String {
                plan = PlanInfo(name: planName)
            }
            
            if let cascadeData = userStatus["cascadeModelConfigData"] as? [String: Any],
               let c = cascadeData["clientModelConfigs"] as? [[String: Any]] {
                configs = c
            }
        } else if let c = data["clientModelConfigs"] as? [[String: Any]] {
            // Direct response from GetCommandModelConfigs
            configs = c
        }
        
        if !configs.isEmpty {
            
            // Deduplicate by normalized label (keep worst-case)
            var deduped: [String: (label: String, remaining: Double, resetTime: String?)] = [:]
            
            for config in configs {
                guard let quotaInfo = config["quotaInfo"] as? [String: Any],
                      let remaining = quotaInfo["remainingFraction"] as? Double,
                      let rawLabel = config["label"] as? String else { continue }
                
                let label = normalizeLabel(rawLabel)
                let resetTime = quotaInfo["resetTime"] as? String
                
                if let existing = deduped[label] {
                    if remaining < existing.remaining {
                        deduped[label] = (label, remaining, resetTime)
                    }
                } else {
                    deduped[label] = (label, remaining, resetTime)
                }
            }
            
            // Sort: Gemini Pro first, then Gemini, then Claude Opus, then Claude, then rest
            let sorted = deduped.values.sorted { a, b in
                sortKey(a.label) < sortKey(b.label)
            }
            
            let periodMs = 5 * 60 * 60 * 1000  // 5 hours
            
            for model in sorted {
                let usedPercent = (1 - model.remaining) * 100
                let resetsAt = model.resetTime.flatMap { parseISO8601($0) }
                
                metrics.append(UsageMetric(
                    label: model.label,
                    usedPercent: usedPercent,
                    format: .percent,
                    period: UsagePeriod(label: "5 hours", resetsAt: resetsAt, durationMs: periodMs)
                ))
            }
        }
        
        return UsageData(account: account, plan: plan, metrics: metrics, settingURL: settingURL)
    }
    
    private func normalizeLabel(_ label: String) -> String {
        // "Gemini 3 Pro (High)" -> "Gemini 3 Pro"
        label.replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func sortKey(_ label: String) -> String {
        let lower = label.lowercased()
        if lower.contains("gemini") && lower.contains("pro") { return "0a_\(label)" }
        if lower.contains("gemini") { return "0b_\(label)" }
        if lower.contains("claude") && lower.contains("opus") { return "1a_\(label)" }
        if lower.contains("claude") { return "1b_\(label)" }
        return "2_\(label)"
    }
    
    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}

/// Delegate to allow self-signed certificates for localhost
private final class InsecureDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
