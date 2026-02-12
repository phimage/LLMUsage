import SwiftUI
import LLMUsage

struct AddAccountFormView: View {
    @EnvironmentObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Account").font(.headline)

            Picker("Service", selection: $viewModel.addService) {
                ForEach(LLMService.allCases, id: \.self) { service in
                    Text(service.displayName).tag(service)
                }
            }

            TextField("Token / API Key", text: $viewModel.addToken)
                .textFieldStyle(.roundedBorder)

            TextField("Label (optional)", text: $viewModel.addLabel)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.showAddForm = false
                }
                Button("Add") {
                    Task { await viewModel.addAccount() }
                }
                .disabled(viewModel.addToken.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
