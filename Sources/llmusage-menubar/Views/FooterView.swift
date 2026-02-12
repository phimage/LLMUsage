import SwiftUI

struct FooterView: View {
    @EnvironmentObject var viewModel: MenuBarViewModel

    var body: some View {
        HStack {
            if viewModel.isRefreshing || viewModel.isDiscovering {
                ProgressView().controlSize(.small)
                Text(viewModel.isDiscovering ? "Discovering..." : "Refreshing...")
                    .font(.caption2).foregroundColor(.secondary)
            } else if let date = viewModel.lastRefreshed {
                Text("Updated \(date, style: .relative) ago")
                    .font(.caption2).foregroundColor(.secondary)
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption)
        }
        .padding(12)
    }
}
