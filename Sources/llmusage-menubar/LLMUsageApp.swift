import SwiftUI
import LLMUsage

@main
struct LLMUsageApp: App {
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(viewModel)
        } label: {
            Label("LLM Usage", systemImage: "gauge.medium")
        }
        .menuBarExtraStyle(.window)
    }
}
