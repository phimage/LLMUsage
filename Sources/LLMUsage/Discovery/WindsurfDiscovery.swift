import Foundation
import SQLite3

/// Discovers Windsurf tokens from SQLite state database
public struct WindsurfDiscovery: TokenDiscoverer {
    public let service = LLMService.windsurf
    
    private let dbPath = "~/Library/Application Support/Windsurf/User/globalStorage/state.vscdb"
    
    public init() {}
    
    public func discover() async throws -> DiscoveryResult? {
        let path = (dbPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        guard let apiKey = try? readApiKey(path: path), !apiKey.isEmpty else {
            return nil
        }
        
        let token = TokenInfo(
            accessToken: apiKey,
            refreshToken: nil,
            expiresAt: nil,
            source: .discovered
        )
        
        return DiscoveryResult(service: .windsurf, tokens: [token], source: "sqlite")
    }
    
    private func readApiKey(path: String) throws -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }
        
        let sql = "SELECT value FROM ItemTable WHERE key = 'windsurfAuthStatus' LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let cString = sqlite3_column_text(stmt, 0) else {
            return nil
        }
        
        let jsonString = String(cString: cString)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiKey = json["apiKey"] as? String else {
            return nil
        }
        
        return apiKey
    }
}
