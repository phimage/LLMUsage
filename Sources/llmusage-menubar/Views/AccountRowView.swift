import SwiftUI
import LLMUsage

struct AccountRowView: View {
    @EnvironmentObject var viewModel: MenuBarViewModel
    @Environment(\.openURL) var openURL
    let account: LLMAccount

    private var usageData: UsageData? { viewModel.usageByAccountID[account.id] }
    private var error: String? { viewModel.errorByAccountID[account.id] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ServiceIconView(service: account.service)

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.service.displayName)
                        .font(.subheadline).bold()
                    Text(account.label)
                        .font(.caption).foregroundColor(.secondary)
                }

                Spacer()

                if let plan = usageData?.plan?.name {
                    Text(plan)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .cornerRadius(4)
                }

                if let settingURL = usageData?.settingURL {
                    Button {
                        openURL(settingURL)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open settings")
                }

                Button {
                    Task { await viewModel.deleteAccount(account) }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Remove account")
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else if let data = usageData {
                if data.metrics.isEmpty {
                    Text("No usage data")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(Array(data.metrics.enumerated()), id: \.offset) { _, metric in
                        MetricRowView(metric: metric)
                    }
                }
            } else {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading...").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(.background.opacity(0.5))
        .cornerRadius(8)
    }
}
