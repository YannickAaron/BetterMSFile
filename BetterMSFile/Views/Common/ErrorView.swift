import SwiftUI

struct ErrorView: View {
    let message: String
    var isOffline: Bool = false
    var retryAction: (() async -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isOffline ? "wifi.slash" : "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(isOffline ? .orange : .red)

            Text(isOffline ? "You're Offline" : "Something Went Wrong")
                .font(.title3)
                .fontWeight(.medium)

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if isOffline {
                Text("Showing cached files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let retryAction {
                Button("Retry") {
                    Task { await retryAction() }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
