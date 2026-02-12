import XCTest
@testable import LLMUsage

final class AntigravityTests: XCTestCase {
    
    func testDiscoveryAndFetch() async throws {
        let discovery = AntigravityDiscovery()
        guard let result = try await discovery.discover() else {
            print("Skipping test: Antigravity not found or not running")
            return
        }
        
        XCTAssertEqual(result.service, .antigravity)
        XCTAssertFalse(result.tokens.isEmpty, "Should find at least one token (port)")
        
        print("Found \(result.tokens.count) tokens")
        for token in result.tokens {
            print(" - \(token.accessToken)")
        }
        
        // Create a dummy account with these tokens
        let account = LLMAccount(
            id: UUID(),
            service: .antigravity,
            label: "Test Account",
            tokens: result.tokens,
            isActive: true
        )
        
        let client = AntigravityClient()
        do {
            let usage = try await client.fetchUsage(account: account)
            print("\nSuccessfully fetched usage!")
            if let plan = usage.plan {
                 print("Plan: \(plan.name)")
            }
            for metric in usage.metrics {
                print("Metric: \(metric.label) - \(metric.usedPercent)% used")
            }
            
            XCTAssertFalse(usage.metrics.isEmpty, "Should return some usage metrics")
            
        } catch {
            XCTFail("Failed to fetch usage: \(error)")
        }
    }
}
