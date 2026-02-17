import SwiftUI
import LLMUsage
import ServiceManagement
import AppKit

struct AccountErrorState {
    let message: String
    let canLaunchAntigravity: Bool
}

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published var accounts: [LLMAccount] = []
    @Published var usageByAccountID: [UUID: UsageData] = [:]
    @Published var errorByAccountID: [UUID: AccountErrorState] = [:]
    @Published var isRefreshing = false
    @Published var isDiscovering = false
    @Published var showAddForm = false
    @Published var isDetached = false
    @Published var lastRefreshed: Date?

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet {
            updateLaunchAtLogin()
        }
    }

    // Add-account form state
    @Published var addService: LLMService = .claude
    @Published var addToken: String = ""
    @Published var addLabel: String = ""

    private let usage = LLMUsage()
    private var refreshTimer: Timer?
    private var detachedPanel: NSPanel?
    private var closeObserver: NSObjectProtocol?

    init() {
        Task { await initialLoad() }
    }

    func initialLoad() async {
        do { try await usage.setup() } catch { /* empty keychain on first launch */ }
        accounts = await usage.getAccounts()
        await refreshUsage()
        startAutoRefresh()
        updateLaunchAtLogin()
    }

    // MARK: - Refresh

    func refreshUsage() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: (UUID, Result<UsageData, Error>).self) { group in
            for account in accounts where account.isActive {
                group.addTask { [usage] in
                    do {
                        let data = try await usage.fetchUsage(account: account)
                        return (account.id, .success(data))
                    } catch {
                        return (account.id, .failure(error))
                    }
                }
            }
            for await (id, result) in group {
                switch result {
                case .success(let data):
                    usageByAccountID[id] = data
                    errorByAccountID.removeValue(forKey: id)
                case .failure(let error):
                    if let account = accounts.first(where: { $0.id == id }),
                       account.service == .antigravity,
                       isNoTokenError(error) {
                        errorByAccountID[id] = AccountErrorState(
                            message: "Antigravity is not running. Launch it, then refresh.",
                            canLaunchAntigravity: true
                        )
                    } else {
                        errorByAccountID[id] = AccountErrorState(
                            message: String(describing: error).prefix(80).description,
                            canLaunchAntigravity: false
                        )
                    }
                }
            }
        }
        lastRefreshed = Date()
    }

    func launchAntigravity() {
        let workspace = NSWorkspace.shared
        let configuration = NSWorkspace.OpenConfiguration()

        let bundleIDs = [
            "com.google.antigravity",
            "com.antigravity.desktop",
            "com.exafunction.antigravity"
        ]

        for bundleID in bundleIDs {
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                workspace.openApplication(at: appURL, configuration: configuration, completionHandler: nil)
                return
            }
        }

        let defaultPaths = [
            "/Applications/Antigravity.app",
            "/Applications/Google Antigravity.app"
        ]
        for path in defaultPaths where FileManager.default.fileExists(atPath: path) {
            workspace.openApplication(
                at: URL(fileURLWithPath: path),
                configuration: configuration,
                completionHandler: nil
            )
            return
        }

        if let url = URL(string: "antigravity://") {
            workspace.open(url)
        }
    }

    // MARK: - Discovery
 
    func discoverAndMerge(service: LLMService? = nil) async {
        isDiscovering = true
        defer { isDiscovering = false }
 
        _ = try? await usage.discoverAndImport(service: service)
        accounts = await usage.getAccounts()
        await refreshUsage()
    }
 
    // MARK: - Account Management
 
    func addAccount() async {
        if addService == .antigravity {
            await discoverAndMerge(service: .antigravity)
        } else {
            let token = TokenInfo(accessToken: addToken, source: .manual)
            let account = LLMAccount(
                service: addService,
                label: addLabel.isEmpty ? "Manual" : addLabel,
                tokens: [token],
                isActive: true
            )
            try? await usage.saveAccount(account)
            accounts = await usage.getAccounts()
        }

        addToken = ""
        addLabel = ""
        showAddForm = false

        await refreshUsage()
    }

    func moveAccounts(from source: IndexSet, to destination: Int) {
        accounts.move(fromOffsets: source, toOffset: destination)
        Task { try? await usage.saveAccountsInOrder(accounts) }
    }

    func deleteAccount(_ account: LLMAccount) async {
        try? await usage.deleteAccount(id: account.id)
        accounts = await usage.getAccounts()
        usageByAccountID.removeValue(forKey: account.id)
        errorByAccountID.removeValue(forKey: account.id)
    }

    func updateAccountLabel(_ account: LLMAccount, newLabel: String) async {
        var updated = account
        updated.label = newLabel
        updated.updatedAt = Date()
        try? await usage.saveAccount(updated)
        accounts = await usage.getAccounts()
    }

    // MARK: - Detach / Attach

    func detach() {
        guard !isDetached else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.contentMinSize = NSSize(width: 340, height: 300)
        panel.setFrameAutosaveName("LLMUsageDetached")
        panel.contentView = NSHostingView(
            rootView: MenuBarContentView(isDetachedWindow: true)
                .ignoresSafeArea(edges: .top)
                .environmentObject(self)
        )
        panel.center()
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isDetached = false
                self?.detachedPanel = nil
                if let obs = self?.closeObserver {
                    NotificationCenter.default.removeObserver(obs)
                    self?.closeObserver = nil
                }
            }
        }

        detachedPanel = panel
        isDetached = true
    }

    func attach() {
        if let obs = closeObserver {
            NotificationCenter.default.removeObserver(obs)
            closeObserver = nil
        }
        detachedPanel?.close()
        detachedPanel = nil
        isDetached = false
    }

    // MARK: - Auto-refresh

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshUsage()
            }
        }
    }

    private func updateLaunchAtLogin() {
        let service = SMAppService.mainApp
        if launchAtLogin {
            try? service.register()
        } else {
            try? service.unregister()
        }
    }

    private func isNoTokenError(_ error: Error) -> Bool {
        guard let usageError = error as? UsageClientError else { return false }
        if case .noToken = usageError {
            return true
        }
        return false
    }
}
