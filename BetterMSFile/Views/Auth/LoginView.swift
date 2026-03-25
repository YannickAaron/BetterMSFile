import SwiftUI

struct LoginView: View {
    let viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            MSAppIcon.oneDrive.icon(size: 64)

            Text("BetterMSFile")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Fast, unified access to your Microsoft 365 files")
                .foregroundStyle(.secondary)

            if viewModel.isLoading {
                ProgressView("Signing in...")
            } else {
                Button {
                    Task { await viewModel.signIn() }
                } label: {
                    HStack(spacing: 8) {
                        MSAppIcon.microsoft.icon(size: 16)
                        Text("Sign in with Microsoft")
                    }
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
