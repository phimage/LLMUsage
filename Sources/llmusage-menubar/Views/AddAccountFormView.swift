import SwiftUI
import LLMUsage

struct AddAccountFormView: View {
    @EnvironmentObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Account").font(.headline)

            Picker("Service", selection: $viewModel.addService) {
                ForEach(LLMService.allCases.filter { service in
                    if service == .antigravity {
                        return !viewModel.accounts.contains(where: { $0.service == .antigravity })
                    }
                    return true
                }, id: \.self) { service in
                    Text(service.displayName).tag(service)
                }
            }

            TextField(viewModel.addService == .antigravity ? "Discovered automatically" : "Token / API Key", text: $viewModel.addToken)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.addService == .antigravity)

            TextField("Label (optional)", text: $viewModel.addLabel)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.showAddForm = false
                }
                Button(viewModel.addService == .antigravity ? "Discover" : "Add") {
                    Task { await viewModel.addAccount() }
                }
                .disabled(viewModel.addService != .antigravity && viewModel.addToken.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
