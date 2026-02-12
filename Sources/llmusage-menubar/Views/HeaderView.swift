import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var viewModel: MenuBarViewModel

    var body: some View {
        HStack {
            if !viewModel.isDetached {
                Text("LLM Usage").font(.headline)
            }
            Spacer()

            Button {
                Task { await viewModel.refreshUsage() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isRefreshing)
            .help("Refresh usage data")

            Button {
                Task { await viewModel.discoverAndMerge() }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .disabled(viewModel.isDiscovering)
            .help("Discover new accounts")

            Button {
                if viewModel.isDetached {
                    viewModel.attach()
                } else {
                    viewModel.detach()
                }
            } label: {
                Image(systemName: viewModel.isDetached ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .help(viewModel.isDetached ? "Return to menu bar" : "Detach into window")

            Button {
                viewModel.showAddForm.toggle()
            } label: {
                Image(systemName: "plus")
            }
            .popover(isPresented: $viewModel.showAddForm) {
                AddAccountFormView()
                    .environmentObject(viewModel)
            }
            .help("Add account manually")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, viewModel.isDetached ? 6 : 12)
    }
}
