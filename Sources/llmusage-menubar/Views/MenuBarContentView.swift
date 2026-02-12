import SwiftUI
import LLMUsage

struct MenuBarContentView: View {
    var isDetachedWindow = false
    @EnvironmentObject var viewModel: MenuBarViewModel
    @AppStorage("menuBarHeight") private var menuBarHeight: Double = 400
    @State private var dragStartHeight: Double?

    var body: some View {
        if !isDetachedWindow && viewModel.isDetached {
            VStack(spacing: 8) {
                Image(systemName: "macwindow")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Window is detached")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button("Return to menu bar") {
                    viewModel.attach()
                }
            }
            .padding(20)
            .frame(width: 220)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HeaderView()
                Divider()

                if viewModel.accounts.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(viewModel.accounts) { account in
                            AccountRowView(account: account)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        }
                        .onMove { source, destination in
                            viewModel.moveAccounts(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.top, 8)
                }

                if !isDetachedWindow {
                    Capsule()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                        }
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    if dragStartHeight == nil { dragStartHeight = menuBarHeight }
                                    menuBarHeight = min(800, max(200, dragStartHeight! + value.translation.height))
                                }
                                .onEnded { _ in
                                    dragStartHeight = nil
                                }
                        )
                }

                Divider()
                FooterView()
            }
            .frame(width: 340)
            .frame(height: isDetachedWindow ? nil : menuBarHeight)
            .background {
                if isDetachedWindow {
                    // Fallback: classic translucent material using NSVisualEffectView
                    MacVisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow, state: .active)
                        .padding(6)
                }
            }
        }
    }
}

