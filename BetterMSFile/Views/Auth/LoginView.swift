import SwiftUI

struct LoginView: View {
    let viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("BetterMSFile")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Fast, unified access to your Microsoft 365 files")
                .foregroundStyle(.secondary)

            if viewModel.isLoading {
                ProgressView("Signing in...")
            } else {
                Button("Sign in with Microsoft") {
                    Task { await viewModel.signIn() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
