import AppKit
import SwiftUI

@MainActor
class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var viewModel: MenuBarViewModel

    init(_ viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
        self.popover = NSPopover()
        self.popover.contentSize = NSSize(width: 340, height: 400)
        self.popover.behavior = .transient
        self.popover.contentViewController = NSHostingController(rootView: MenuBarContentView().environmentObject(viewModel))

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = self.statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "LLM Usage")
            button.action = #selector(handleAction(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc func handleAction(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusItem.button {
                // Adjust height before showing
                let height = UserDefaults.standard.double(forKey: "menuBarHeight")
                if height > 0 {
                    popover.contentSize = NSSize(width: 340, height: height)
                }
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = viewModel.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.popUpMenu(menu)
    }

    @objc func toggleLaunchAtLogin() {
        viewModel.launchAtLogin.toggle()
    }
}
