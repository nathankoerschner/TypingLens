import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var appState: AppState
    let viewModel: SettingsViewModel

    var body: some View {
        let state = viewModel.state(for: appState)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TypingLens")
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.primary)
                    Text("Use the Monkeytype palette here too: muted chrome, warm accent, mono-heavy UI.")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.subdued)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Toggle(
                        isOn: Binding(
                            get: { state.launchAtLoginEnabled },
                            set: { viewModel.toggleLaunchAtLogin($0) }
                        )
                    ) {
                        SettingsRowLabel(title: "Launch at login", value: state.launchAtLoginEnabled ? "Enabled" : "Disabled")
                    }
                    .toggleStyle(.switch)
                    .tint(TypingLensTheme.primary)

                    Divider().overlay(TypingLensTheme.panelElevated)

                    SettingsRowLabel(title: "Permission", value: state.permissionStatus)
                    SettingsRowLabel(title: "Logging", value: state.loggingStatus)

                    HStack(spacing: 10) {
                        Button("Refresh", action: viewModel.refreshPermissionStatus)
                            .buttonStyle(TypingLensFilledButtonStyle())
                        Button("Open System Settings", action: viewModel.openSystemSettings)
                            .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.primary, foregroundColor: TypingLensTheme.background))
                    }
                }
                .typingLensCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Transcript")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .textCase(.uppercase)
                        .foregroundStyle(TypingLensTheme.subdued)
                    Text(state.transcriptPath)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.text)
                        .textSelection(.enabled)

                    HStack(spacing: 10) {
                        Button("Reveal in Finder", action: viewModel.revealTranscript)
                            .buttonStyle(TypingLensFilledButtonStyle())
                        Button("Clear Transcript", action: viewModel.clearTranscript)
                            .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.errorMuted, foregroundColor: TypingLensTheme.text))
                    }
                }
                .typingLensCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .textCase(.uppercase)
                        .foregroundStyle(TypingLensTheme.subdued)

                    HStack(spacing: 10) {
                        Button("Extract Words", action: viewModel.extractWords)
                            .buttonStyle(TypingLensFilledButtonStyle())
                        Button("Export Ranked Words", action: viewModel.exportRankedWords)
                            .buttonStyle(TypingLensFilledButtonStyle())
                        Button("Practice Now", action: viewModel.practiceNow)
                            .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.primary, foregroundColor: TypingLensTheme.background))
                    }
                }
                .typingLensCard()

                VStack(alignment: .leading, spacing: 8) {
                    if let message = state.currentErrorMessage {
                        Text("Error: \(message)")
                            .foregroundStyle(TypingLensTheme.error)
                    }

                    if let extractionStatus = state.extractionStatus {
                        Text(extractionStatus)
                            .foregroundStyle(TypingLensTheme.subdued)
                    }

                    if let rankedExportStatus = state.rankedExportStatus {
                        Text(rankedExportStatus)
                            .foregroundStyle(TypingLensTheme.subdued)
                    }

                    if let practiceStatus = state.practiceStatus {
                        Text(practiceStatus)
                            .foregroundStyle(TypingLensTheme.subdued)
                    }
                }
                .font(.system(size: 12, weight: .regular, design: .monospaced))
            }
            .padding(20)
        }
        .frame(width: 640)
        .background(TypingLensTheme.background)
        .foregroundStyle(TypingLensTheme.text)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .textCase(.uppercase)
                .foregroundStyle(TypingLensTheme.subdued)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(TypingLensTheme.text)
                .multilineTextAlignment(.trailing)
        }
    }
}
