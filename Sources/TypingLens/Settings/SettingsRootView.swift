import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var appState: AppState
    let viewModel: SettingsViewModel

    var body: some View {
        let state = viewModel.state(for: appState)

        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TypingLensTitleLockup()

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
                                .frame(maxWidth: .infinity)
                                .buttonStyle(TypingLensFilledButtonStyle())
                            Button("Open System Settings", action: viewModel.openSystemSettings)
                                .frame(maxWidth: .infinity)
                                .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.primary, foregroundColor: TypingLensTheme.background))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                                .frame(maxWidth: .infinity)
                                .buttonStyle(TypingLensFilledButtonStyle())
                            Button("Clear Transcript", action: viewModel.clearTranscript)
                                .frame(maxWidth: .infinity)
                                .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.errorMuted, foregroundColor: TypingLensTheme.text))
                        }

                        HStack(spacing: 10) {
                            Button("Practice Now", action: viewModel.practiceNow)
                                .frame(maxWidth: .infinity)
                                .buttonStyle(TypingLensFilledButtonStyle())
                            Button("Open Analytics", action: viewModel.openAnalytics)
                                .frame(maxWidth: .infinity)
                                .buttonStyle(TypingLensFilledButtonStyle())
                            Button("Open Finger Calibration", action: viewModel.openFingerCalibration)
                                .frame(maxWidth: .infinity)
                                .buttonStyle(TypingLensFilledButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

                        if let analyticsStatus = state.analyticsStatus {
                            Text(analyticsStatus)
                                .foregroundStyle(TypingLensTheme.subdued)
                        }

                        if let fingerCalibrationStatus = state.fingerCalibrationStatus {
                            Text(fingerCalibrationStatus)
                                .foregroundStyle(TypingLensTheme.subdued)
                        }
                    }
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                }
                .padding(.horizontal, 20)
                .padding(.top, max(20, proxy.safeAreaInsets.top + 8))
                .padding(.bottom, 20)
            }
            .frame(width: 640)
            .background(TypingLensTheme.background)
            .foregroundStyle(TypingLensTheme.text)
        }
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
