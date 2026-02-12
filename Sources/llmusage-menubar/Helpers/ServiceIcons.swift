import SwiftUI
import LLMUsage

/// Returns the SVG file name (without extension) for a service, if one exists.
func serviceLogoName(for service: LLMService) -> String? {
    switch service {
    case .claude: "claude"
    case .copilot: "githubcopilot"
    case .codex: "openai"
    case .cursor: "cursor"
    case .windsurf: "windsurf"
    case .antigravity: "google-antigravity"
    }
}

/// SF Symbol fallback for services without a custom SVG logo.
func serviceIcon(for service: LLMService) -> String {
    switch service {
    case .claude: "brain.head.profile"
    case .copilot: "airplane"
    case .cursor: "cursorarrow.rays"
    case .windsurf: "wind"
    case .antigravity: "arrow.up.circle"
    case .codex: "book.closed"
    }
}

func serviceColor(for service: LLMService) -> Color {
    switch service {
    case .claude: .orange
    case .copilot: .blue
    case .cursor: .purple
    case .windsurf: .green
    case .antigravity: .indigo
    case .codex: .purple
    }
}

/// Loads an SVG from the bundle's ServiceLogos directory as a template NSImage.
private func loadServiceLogo(_ name: String) -> NSImage? {
    guard let url = Bundle.module.url(
        forResource: name, withExtension: "svg", subdirectory: "ServiceLogos"
    ) else { return nil }
    guard let image = NSImage(contentsOf: url) else { return nil }
    image.isTemplate = true
    return image
}

/// Displays either a custom SVG logo or an SF Symbol for a service, tinted with the service color.
struct ServiceIconView: View {
    let service: LLMService

    var body: some View {
        if let logoName = serviceLogoName(for: service),
           let nsImage = loadServiceLogo(logoName) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundColor(serviceColor(for: service))
        } else {
            Image(systemName: serviceIcon(for: service))
                .foregroundColor(serviceColor(for: service))
        }
    }
}
