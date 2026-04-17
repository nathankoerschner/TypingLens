import SwiftUI

struct FingerCalibrationRootView: View {
    @ObservedObject var viewModel: FingerCalibrationViewModel
    let onClose: () -> Void

    @State private var keyboardDragTranslation = CGSize.zero
    @State private var draggedKeyID: String?
    @State private var keyDragTranslation = CGSize.zero
    var body: some View {
        HStack(spacing: 16) {
            leftRail
                .frame(minWidth: 260)

            mainCanvas
                .frame(minWidth: 420)

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
                Text("Canvas")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                Text(viewModel.calibrationStatus)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)

                TextField("Calibration name", text: $viewModel.draftCalibrationName)
                    .textFieldStyle(.roundedBorder)

                Button(viewModel.isFrozen ? "Resume Live" : "Freeze Frame") {
                    viewModel.isFrozen ? viewModel.resumeLiveFrame() : viewModel.freezeFrame()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(TypingLensFilledButtonStyle())

                HStack(spacing: 10) {
                    Button("Save Calibration") {
                        viewModel.saveCalibration()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(TypingLensFilledButtonStyle())

                    Button("Reset Calibration") {
                        viewModel.resetCalibration()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.errorMuted, foregroundColor: TypingLensTheme.text))
                }

                if let selected = viewModel.selectedKeyLabel {
                    Text("Selected key: \(selected)")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.subdued)
                } else {
                    Text("No key selected")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.subdued)
                }
            }

            TypingLensPanelCard {
                Text("Saved Calibrations")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))

                if viewModel.savedCalibrations.isEmpty {
                    Text("No saved calibrations")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.subdued)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.savedCalibrations) { summary in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(summary.name)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    Text(summary.updatedAt, style: .time)
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundStyle(TypingLensTheme.subdued)

                                    HStack(spacing: 8) {
                                        Button("Load") {
                                            viewModel.loadCalibration(id: summary.id)
                                        }
                                        .buttonStyle(TypingLensFilledButtonStyle())

                                        Button("Delete") {
                                            viewModel.deleteCalibration(summary.id)
                                        }
                                        .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.errorMuted, foregroundColor: TypingLensTheme.text))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(TypingLensTheme.panelElevated.opacity(0.4))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }

            Spacer(minLength: 0)

            Button("Close", action: onClose)
                .frame(maxWidth: .infinity)
                .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.errorMuted, foregroundColor: TypingLensTheme.text))
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var mainCanvas: some View {
        TypingLensPanelCard {
            Text("Keyboard Layout")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .padding(.bottom, 4)

            GeometryReader { geometry in
                ZStack {
                    TypingLensTheme.panel
                        .opacity(0.3)

                    if let activeCalibration = viewModel.activeCalibration {
                        ForEach(KeyboardCalibrationLayout.supportedKeys) { key in
                            if let frame = viewModel.projectedKeys[key.id] {
                                KeyTargetView(
                                    key: key,
                                    frame: frame,
                                    isSelected: viewModel.selectedKeyID == key.id
                                ) {
                                    if viewModel.isFrozen {
                                        viewModel.selectKey(key.id)
                                    }
                                }
                                .highPriorityGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            guard viewModel.isFrozen else { return }

                                            if draggedKeyID != key.id {
                                                draggedKeyID = key.id
                                                keyDragTranslation = .zero
                                                viewModel.selectKey(key.id)
                                            }

                                            let delta = CGSize(
                                                width: value.translation.width - keyDragTranslation.width,
                                                height: value.translation.height - keyDragTranslation.height
                                            )

                                            keyDragTranslation = value.translation
                                            viewModel.moveSelectedKey(by: delta)
                                        }
                                        .onEnded { _ in
                                            guard viewModel.isFrozen else { return }
                                            guard draggedKeyID == key.id else { return }

                                            draggedKeyID = nil
                                            keyDragTranslation = .zero
                                        }
                                )
                            }
                        }

                        Text("Active calibration: \(activeCalibration.name)")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(TypingLensTheme.subdued)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(TypingLensTheme.background)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .position(x: 12, y: 12)
                    } else {
                        Text("No active calibration")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(TypingLensTheme.subdued)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard viewModel.isFrozen else { return }

                            let delta = CGSize(
                                width: value.translation.width - keyboardDragTranslation.width,
                                height: value.translation.height - keyboardDragTranslation.height
                            )

                            keyboardDragTranslation = value.translation
                            viewModel.moveKeyboard(by: delta)
                        }
                        .onEnded { _ in
                            guard viewModel.isFrozen else { return }
                            keyboardDragTranslation = .zero
                        }
                )
                .onAppear {
                    viewModel.updateCanvasSize(geometry.size)
                }
                .onChange(of: geometry.size) { newSize in
                    viewModel.updateCanvasSize(newSize)
                }
            }
            .frame(minHeight: 440)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(TypingLensTheme.panelElevated, lineWidth: 1)
            )
        }
    }

    private var rightRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            TypingLensPanelCard {
                Text("System State")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))

                Text("Camera: \(viewModel.cameraStatus)")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)

                Text("Tracking: \(viewModel.trackingStatus)")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)

                Text("Key count: \(KeyboardCalibrationLayout.supportedKeys.count)")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)
            }

            TypingLensPanelCard {
                Text("Recent Events")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .padding(.bottom, 4)

                if viewModel.recentEventSummary.isEmpty {
                    Text("No events yet")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.subdued)
                } else {
                    ScrollView {
                        Text(viewModel.recentEventSummary.joined(separator: "\n"))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(TypingLensTheme.text)
                    }
                }
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

private struct KeyTargetView: View {
    let key: KeyboardKeyDefinition
    let frame: CGRect
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let targetDimension = min(
            22,
            max(12, min(frame.width, frame.height) * 0.5)
        )

        Circle()
            .fill(isSelected ? TypingLensTheme.accent.opacity(0.35) : TypingLensTheme.primary.opacity(0.18))
            .overlay {
                Circle()
                    .stroke(isSelected ? TypingLensTheme.accent : TypingLensTheme.subdued.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            }
            .frame(width: targetDimension, height: targetDimension)
            .overlay {
                Text(key.label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.text)
                    .allowsTightening(false)
            }
            .contentShape(Circle())
            .onTapGesture(perform: onTap)
            .position(x: frame.midX, y: frame.midY)
    }
}
