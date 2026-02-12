// MacVisualEffectView.swift
// A small SwiftUI wrapper around NSVisualEffectView for macOS fallback translucency.

import SwiftUI
import AppKit

#if os(macOS)
public struct MacVisualEffectView: NSViewRepresentable {
    public enum Material {
        case appearanceBased
        case light
        case dark
        case titlebar
        case selection
        case menu
        case popover
        case sidebar
        case headerView
        case sheet
        case windowBackground
        case hudWindow
        case fullScreenUI
        case toolTip
        case contentBackground
        case underWindowBackground
        case underPageBackground

        var nsMaterial: NSVisualEffectView.Material {
            switch self {
            case .appearanceBased: return .appearanceBased
            case .light: return .light
            case .dark: return .dark
            case .titlebar: return .titlebar
            case .selection: return .selection
            case .menu: return .menu
            case .popover: return .popover
            case .sidebar: return .sidebar
            case .headerView: return .headerView
            case .sheet: return .sheet
            case .windowBackground: return .windowBackground
            case .hudWindow: return .hudWindow
            case .fullScreenUI: return .fullScreenUI
            case .toolTip: return .toolTip
            case .contentBackground: return .contentBackground
            case .underWindowBackground: return .underWindowBackground
            case .underPageBackground: return .underPageBackground
            }
        }
    }

    public enum BlendingMode {
        case behindWindow
        case withinWindow

        var nsMode: NSVisualEffectView.BlendingMode {
            switch self {
            case .behindWindow: return .behindWindow
            case .withinWindow: return .withinWindow
            }
        }
    }

    private let material: Material
    private let blendingMode: BlendingMode
    private let state: NSVisualEffectView.State
    private let emphasized: Bool

    public init(material: Material = .contentBackground,
                blendingMode: BlendingMode = .withinWindow,
                state: NSVisualEffectView.State = .active,
                emphasized: Bool = false) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.emphasized = emphasized
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = state
        view.blendingMode = blendingMode.nsMode
        view.material = material.nsMaterial
        view.isEmphasized = emphasized
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = state
        nsView.blendingMode = blendingMode.nsMode
        nsView.material = material.nsMaterial
        nsView.isEmphasized = emphasized
    }
}
#endif
