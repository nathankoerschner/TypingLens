import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var appState: AppState
    let viewModel: SettingsViewModel

    var body: some View {
        let state = viewModel.state(for: appState)

        Form {
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { state.launchAtLoginEnabled },
                    set: { viewModel.toggleLaunchAtLogin($0) }
                )
            )

            LabeledContent("Permission") {
                Text(state.permissionStatus)
            }

            HStack {
                Button("Refresh", action: viewModel.refreshPermissionStatus)
                Button("Open System Settings", action: viewModel.openSystemSettings)
            }

            LabeledContent("Transcript") {
                Text(state.transcriptPath)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }

            LabeledContent("Logging") {
                Text(state.loggingStatus)
            }

            if let message = state.currentErrorMessage {
                Text("Error: \(message)")
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Reveal in Finder", action: viewModel.revealTranscript)
                Button("Clear Transcript", role: .destructive, action: viewModel.clearTranscript)
            }
        }
        .padding()
        .frame(width: 560)
    }
}
