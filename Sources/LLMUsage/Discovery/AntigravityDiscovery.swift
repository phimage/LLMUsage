import Foundation

/// Discovers Antigravity by finding the running language server process
public struct AntigravityDiscovery: TokenDiscoverer {
    public let service = LLMService.antigravity
    
    public init() {}
    
    public func discover() async throws -> DiscoveryResult? {
        // Find all language_server_macos processes
        let tokens = await findLanguageServers()
        
        guard !tokens.isEmpty else {
            return nil
        }
        

        
        return DiscoveryResult(service: .antigravity, tokens: tokens, source: "process")
    }
    // MARK: - Private Helpers
    private struct AntigravityProcessInfo {
        let pid: Int
        let csrf: String
    }
    
    private func findLanguageServers() async -> [TokenInfo] {
        // 1. Find PIDs and CSRF tokens from ps
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axww", "-o", "pid,args"]
        task.environment = ProcessInfo.processInfo.environment
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        var tokens: [TokenInfo] = []
        
        do {
            try task.run()
            
            var outputData = Data()
            for try await byte in pipe.fileHandleForReading.bytes {
                outputData.append(byte)
            }
            
            task.waitUntilExit()
            
            let output = String(decoding: outputData, as: UTF8.self)
            let lines = output.components(separatedBy: .newlines)
            
            for line in lines {
                if line.contains("language_server_macos") && line.contains("antigravity") {
                    if let info = parseProcessLine(line) {
                        // 2. For each PID, find listening ports using lsof
                        let ports = await findListeningPorts(pid: info.pid)
                        
                        for port in ports {
                            let tokenData = "\(port):\(info.csrf)"
                            tokens.append(TokenInfo(
                                accessToken: tokenData,
                                refreshToken: nil,
                                expiresAt: nil,
                                source: .discovered
                            ))
                        }
                    }
                }
            }
        } catch {
            print("AntigravityDiscovery error: \(error)")
            return []
        }
        
        return tokens
    }
    
    private func parseProcessLine(_ line: String) -> AntigravityProcessInfo? {
        let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        
        guard let pidStr = parts.first, let pid = Int(pidStr) else { return nil }
        
        var csrf: String?
        
        for (i, part) in parts.enumerated() {
            if part == "--csrf_token" && i + 1 < parts.count {
                csrf = parts[i + 1]
            } else if part.hasPrefix("--csrf_token=") {
                csrf = String(part.dropFirst("--csrf_token=".count))
            }
        }
        
        if let csrf {
            return AntigravityProcessInfo(pid: pid, csrf: csrf)
        }
        return nil
    }
    
    private func findListeningPorts(pid: Int) async -> [Int] {
        let task = Process()
        // Use lsof to find TCP listening ports for the PID
        // -P: no port names, -n: no host names, -iTCP: only TCP, -sTCP:LISTEN: only listening
        // -a: AND condition (PID AND TCP AND LISTEN)
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-p", "\(pid)", "-P", "-n", "-iTCP", "-sTCP:LISTEN", "-a"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice // lsof might warn if not root, ignore stderr
        
        do {
            try task.run()
            
            var outputData = Data()
            for try await byte in pipe.fileHandleForReading.bytes {
                outputData.append(byte)
            }
            
            task.waitUntilExit()
            
            let output = String(decoding: outputData, as: UTF8.self)
            var ports: [Int] = []
            
            // Example output:
            // COMMAND     PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
            // language_ 27651 eric   20u  IPv4 0x304a811fa5c9e162      0t0  TCP 127.0.0.1:60269 (LISTEN)
            
            let lines = output.components(separatedBy: .newlines)
            for line in lines.dropFirst() { // Skip header
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                // We want the last column usually, or the one containing TCP
                if let tcpPart = parts.first(where: { $0.contains("TCP") && $0.contains(":") }) {
                    // 127.0.0.1:60269 or *:60269
                    let addrParts = tcpPart.split(separator: ":")
                    if let portStr = addrParts.last?.replacingOccurrences(of: "(LISTEN)", with: ""),
                       let port = Int(portStr) {
                        ports.append(port)
                    }
                } else if let last = parts.last, last.contains("(LISTEN)") {
                     // sometimes format is different, check last part e.g. "127.0.0.1:60269 (LISTEN)"
                     // but usually lsof separates (LISTEN)
                     // Let's try to find the part with x.x.x.x:PORT
                     for part in parts {
                         if part.contains(":") && !part.contains("IPv") && !part.contains("TCP") {
                             let addrParts = part.split(separator: ":")
                             if let portStr = addrParts.last, let port = Int(portStr) {
                                 ports.append(port)
                             }
                         }
                     }
                }
            }
            
            return ports
            
        } catch {
             print("AntigravityDiscovery lsof error: \(error)")
             return []
        }
    }
}
