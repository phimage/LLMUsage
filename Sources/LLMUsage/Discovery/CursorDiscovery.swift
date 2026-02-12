import Foundation
import SQLite3

/// Discovers Cursor tokens from SQLite state database
public struct CursorDiscovery: TokenDiscoverer {
    public let service = LLMService.cursor
    
    private let dbPath = "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    
    public init() {}
    
    public func discover() async throws -> DiscoveryResult? {
        let path = (dbPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        let accessToken = try? readStateValue(path: path, key: "cursorAuth/accessToken")
        let refreshToken = try? readStateValue(path: path, key: "cursorAuth/refreshToken")
        
        guard let accessToken, !accessToken.isEmpty else { return nil }
        
        // Decode JWT to get expiration
        let expiresAt = decodeJWTExpiration(accessToken)
        
        let token = TokenInfo(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            source: .discovered
        )
        
        return DiscoveryResult(service: .cursor, tokens: [token], source: "sqlite")
    }
    
    private func readStateValue(path: String, key: String) throws -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }
        
        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, key, -1, nil)
        
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        
        guard let cString = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: cString)
    }
    
    private func decodeJWTExpiration(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        
        var base64 = String(parts[1])
        // Pad to multiple of 4
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else {
            return nil
        }
        
        return Date(timeIntervalSince1970: exp)
    }
}
