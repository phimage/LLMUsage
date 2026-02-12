import SwiftUI
import LLMUsage

@main
struct LLMUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: MenuBarViewModel!
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = MenuBarViewModel()
        statusBarController = StatusBarController(viewModel)
    }
}
