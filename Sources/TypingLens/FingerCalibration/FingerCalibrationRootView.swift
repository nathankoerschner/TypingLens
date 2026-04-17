import SwiftUI

struct FingerCalibrationRootView: View {
    @ObservedObject var viewModel: FingerCalibrationViewModel
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            leftRail
                .frame(minWidth: 260)

            ZStack {
                TypingLensTheme.panel
                    .opacity(0.32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(TypingLensTheme.panelElevated, lineWidth: 1)
                    )
                    .overlay(
                        VStack {
                            Text("Live Camera Preview")
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundStyle(TypingLensTheme.subdued)
                            Text("Placeholder canvas")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(TypingLensTheme.subdued)
                        }
                    )
            }
            .typingLensCard()

            rightRail
                .frame(minWidth: 260)
        }
        .padding(20)
        .background(TypingLensTheme.background)
        .foregroundStyle(TypingLensTheme.text)
    }

    private var leftRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finger Calibration")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))

            TypingLensPanelCard {
                Text("Camera")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                Text(viewModel.cameraStatus)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)
            }

            TypingLensPanelCard {
                Text("Calibration")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                Text(viewModel.calibrationStatus)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)
            }

            TypingLensPanelCard {
                Text("Tracking")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                Text(viewModel.trackingStatus)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)
            }

            Spacer(minLength: 0)

            Button("Close", action: onClose)
                .frame(maxWidth: .infinity)
                .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.errorMuted, foregroundColor: TypingLensTheme.text))
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var rightRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            TypingLensPanelCard {
                Text("Recent Events")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .padding(.bottom, 4)

                if viewModel.recentEventSummary.isEmpty {
                    Text("No events yet")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.subdued)
                } else {
                    Text(viewModel.recentEventSummary.joined(separator: "\n"))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.text)
                        .textSelection(.enabled)
                }
            }

            TypingLensPanelCard {
                Text("Selected Key")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                Text(viewModel.selectedKeyLabel ?? "None")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct TypingLensPanelCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TypingLensTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TypingLensTheme.panelElevated, lineWidth: 1)
        )
    }
}
