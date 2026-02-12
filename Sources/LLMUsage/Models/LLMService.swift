import Foundation

/// Supported LLM services
public enum LLMService: String, Codable, CaseIterable, Sendable {
    case claude
    case copilot
    case cursor
    case windsurf
    case antigravity
    case codex
    
    public var displayName: String {
        switch self {
        case .claude: "Claude"
        case .copilot: "GitHub Copilot"
        case .cursor: "Cursor"
        case .windsurf: "Windsurf"
        case .antigravity: "Antigravity"
        case .codex: "Codex"
        }
    }
}
