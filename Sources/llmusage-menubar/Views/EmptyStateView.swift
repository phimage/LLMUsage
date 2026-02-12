import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No accounts found")
                .font(.subheadline).bold()

            Text("Click the refresh button to discover accounts, or add one manually with +.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Discover Now") {
                Task { await viewModel.discoverAndMerge() }
            }
            .disabled(viewModel.isDiscovering)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
