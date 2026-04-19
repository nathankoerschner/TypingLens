import AppKit
import SwiftUI

private let previewCoordinateSpace = "fingerAccuracyPreview"

struct FingerAccuracyRootView: View {
    @StateObject private var viewModel: FingerAccuracyViewModel
    let onClose: () -> Void

    init(viewModel: FingerAccuracyViewModel = FingerAccuracyViewModel(), onClose: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            if !viewModel.mode.isCalibrating {
                promptPanel
            }
            preview
            toolbar
            resultsList
        }
        .padding(20)
        .frame(minWidth: 960, minHeight: 780)
        .background(TypingLensTheme.background)
        .foregroundStyle(TypingLensTheme.text)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Finger Accuracy")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(instructionText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(TypingLensTheme.subdued)
            }
            Spacer()
            Button("Close", action: onClose)
                .buttonStyle(TypingLensFilledButtonStyle())
        }
    }

    private var instructionText: String {
        switch viewModel.mode {
        case .calibrating:
            return "Drag the labeled corners to match your keyboard. The letters show where keys will map."
        case .typing:
            if let pct = viewModel.accuracyPercent {
                return String(format: "Type the prompt with the correct finger • Accuracy: %.0f%%", pct)
            }
            return "Type the prompt with the correct finger and follow the highlighted target."
        }
    }

    private var promptPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Touch typing game")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Target: \(viewModel.currentTargetLabel) • Progress: \(viewModel.promptProgressLabel)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(TypingLensTheme.subdued)
                }

                Spacer()

                if let feedback = viewModel.promptFeedback {
                    Text(feedback)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.promptFeedbackIsSuccess ? Color.black : Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.promptFeedbackIsSuccess
                            ? Color(nsColor: .systemGreen)
                            : Color(nsColor: .systemRed),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
            }

            FingerAccuracyPromptView(
                text: viewModel.promptText,
                currentIndex: viewModel.currentPromptIndex
            )
        }
        .padding(18)
        .background(TypingLensTheme.panel, in: RoundedRectangle(cornerRadius: 24))
    }

    private var preview: some View {
        GeometryReader { proxy in
            let imageRect = Self.imageDisplayRect(imageSize: viewModel.frame?.size, in: proxy.size)
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(TypingLensTheme.panel)

                if let frame = viewModel.frame {
                    Image(decorative: frame.cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    placeholderBody
                }

                FingerAccuracyOverlayView(
                    overlay: viewModel.overlay,
                    calibration: viewModel.calibration,
                    mode: viewModel.mode,
                    latestResult: viewModel.results.first,
                    fingertips: viewModel.fingertips,
                    imageRect: imageRect
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .allowsHitTesting(false)

                if viewModel.mode.isCalibrating, viewModel.frame != nil {
                    ForEach(CalibrationCorner.allCases, id: \.rawValue) { corner in
                        CalibrationHandle(
                            corner: corner,
                            visionPoint: viewModel.calibration.corner(corner),
                            imageRect: imageRect
                        ) { newPoint in
                            viewModel.setCorner(corner, to: newPoint)
                        }
                    }
                }

                FingerAccuracyKeyCaptureView(
                    isDisabled: viewModel.frame == nil || viewModel.mode.isCalibrating,
                    onKey: viewModel.handleKeyDown
                )
                .allowsHitTesting(false)
                .frame(width: 1, height: 1)
                .opacity(0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .coordinateSpace(name: previewCoordinateSpace)
        }
        .frame(minHeight: 420)
    }

    private static func imageDisplayRect(imageSize: CGSize?, in container: CGSize) -> CGRect {
        guard let imageSize,
              imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height
        if imageAspect > containerAspect {
            let height = container.width / imageAspect
            return CGRect(x: 0, y: (container.height - height) / 2, width: container.width, height: height)
        } else {
            let width = container.height * imageAspect
            return CGRect(x: (container.width - width) / 2, y: 0, width: width, height: container.height)
        }
    }

    private var placeholderBody: some View {
        VStack(spacing: 14) {
            Image(systemName: viewModel.permissionDenied ? "camera.slash.fill" : "camera.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(TypingLensTheme.subdued)
            Text(viewModel.statusText)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(TypingLensTheme.text)
            if viewModel.permissionDenied {
                Button("Retry Camera Access") {
                    viewModel.requestCameraAccess()
                }
                .buttonStyle(TypingLensFilledButtonStyle())
            }
        }
        .padding(24)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if viewModel.mode.isCalibrating {
                Button("Done Calibrating") { viewModel.finishCalibration() }
                    .buttonStyle(TypingLensFilledButtonStyle(
                        backgroundColor: TypingLensTheme.primary,
                        foregroundColor: .black
                    ))
                Button("Reset Corners") { viewModel.resetCalibration() }
                    .buttonStyle(TypingLensFilledButtonStyle())
            } else {
                Button("Recalibrate") { viewModel.beginCalibration() }
                    .buttonStyle(TypingLensFilledButtonStyle())
                    .disabled(viewModel.frame == nil)
                Button("Restart Prompt") { viewModel.restartPrompt() }
                    .buttonStyle(TypingLensFilledButtonStyle())
            }

            Button(viewModel.swapHands ? "Swap Hands: ON" : "Swap Hands: OFF") {
                viewModel.toggleSwapHands()
            }
            .buttonStyle(TypingLensFilledButtonStyle())

            Button("Clear Results") { viewModel.clearResults() }
                .buttonStyle(TypingLensFilledButtonStyle())
                .disabled(viewModel.results.isEmpty)

            Spacer()

            Text(viewModel.statusText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(TypingLensTheme.subdued)
        }
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent keystrokes")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(TypingLensTheme.subdued)

            if viewModel.results.isEmpty {
                Text("No keystrokes yet")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.results) { result in
                            AttributionChip(result: result)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .typingLensCard()
    }
}

private struct FingerAccuracyPromptView: View {
    let text: String
    let currentIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                    Text(character == " " ? "␣" : String(character))
                        .font(.system(size: 20, weight: index == currentIndex ? .black : .medium, design: .monospaced))
                        .foregroundStyle(color(for: index))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .background(background(for: index), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func color(for index: Int) -> Color {
        if index <= currentIndex {
            return Color.black
        }
        return TypingLensTheme.text
    }

    private func background(for index: Int) -> Color {
        if index < currentIndex {
            return Color(nsColor: .systemGreen).opacity(0.9)
        }
        if index == currentIndex {
            return Color(nsColor: .systemYellow).opacity(0.95)
        }
        return TypingLensTheme.panelElevated
    }
}

private struct CalibrationHandle: View {
    let corner: CalibrationCorner
    let visionPoint: CGPoint
    let imageRect: CGRect
    let onMove: (CGPoint) -> Void

    var body: some View {
        let displayX = imageRect.minX + (1 - visionPoint.x) * imageRect.width
        let displayY = imageRect.minY + (1 - visionPoint.y) * imageRect.height

        ZStack {
            Circle()
                .fill(Color.cyan)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(Color.black.opacity(0.65), lineWidth: 2))
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)

            Text(corner.shortLabel)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black)
        }
        .contentShape(Circle().inset(by: -14))
        .position(x: displayX, y: displayY)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(previewCoordinateSpace))
                .onChanged { value in
                    guard imageRect.width > 0, imageRect.height > 0 else { return }
                    let vx = 1 - (value.location.x - imageRect.minX) / imageRect.width
                    let vy = 1 - (value.location.y - imageRect.minY) / imageRect.height
                    onMove(CGPoint(x: vx, y: vy))
                }
        )
    }
}

private struct AttributionChip: View {
    let result: AttributionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(displayChar)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                Image(systemName: symbolName)
                    .foregroundStyle(symbolColor)
            }
            Text("exp: \(result.expectedFingerDisplayName)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(TypingLensTheme.subdued)
            Text("got: \(result.detectedFinger?.displayName ?? "—")")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(TypingLensTheme.subdued)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(TypingLensTheme.panelElevated)
        )
    }

    private var displayChar: String {
        result.character == " " ? "␣" : String(result.character)
    }

    private var symbolName: String {
        if result.detectedFinger == nil { return "questionmark.circle" }
        return result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var symbolColor: Color {
        if result.detectedFinger == nil { return TypingLensTheme.subdued }
        return result.isCorrect ? .green : TypingLensTheme.error
    }
}

private struct FingerAccuracyOverlayView: View {
    let overlay: VisionTrackingOverlayState
    let calibration: KeyboardCalibration
    let mode: FingerAccuracyViewModel.Mode
    let latestResult: AttributionResult?
    let fingertips: [FingertipSample]
    let imageRect: CGRect

    var body: some View {
        Canvas { context, _ in
            drawHandStrokes(context: context)
            drawHandPoints(context: context)
            drawCalibrationQuad(context: context)
            drawKeyGrid(context: context)
            drawLatestAttribution(context: context)
        }
    }

    private func mapped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: imageRect.minX + (1 - point.x) * imageRect.width,
            y: imageRect.minY + (1 - point.y) * imageRect.height
        )
    }

    private func drawHandStrokes(context: GraphicsContext) {
        for stroke in overlay.handStrokes {
            var path = Path()
            guard let first = stroke.points.first else { continue }
            path.move(to: mapped(first))
            for point in stroke.points.dropFirst() {
                path.addLine(to: mapped(point))
            }
            context.stroke(path, with: .color(Color(nsColor: .systemOrange).opacity(0.9)), lineWidth: 3)
        }
    }

    private func drawHandPoints(context: GraphicsContext) {
        for point in overlay.handPoints {
            let center = mapped(CGPoint(x: point.x, y: point.y))
            let rect = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: rect), with: .color(Color(nsColor: .systemOrange)))
        }
    }

    private func drawCalibrationQuad(context: GraphicsContext) {
        var quadPath = Path()
        let corners = CalibrationCorner.allCases
        for (i, corner) in corners.enumerated() {
            let point = mapped(calibration.corner(corner))
            if i == 0 { quadPath.move(to: point) } else { quadPath.addLine(to: point) }
        }
        quadPath.closeSubpath()

        let fill = Color.cyan.opacity(mode.isCalibrating ? 0.12 : 0.04)
        context.fill(quadPath, with: .color(fill))
        context.stroke(
            quadPath,
            with: .color(mode.isCalibrating ? Color.cyan.opacity(0.7) : Color.cyan.opacity(0.35)),
            style: StrokeStyle(lineWidth: 2, dash: mode.isCalibrating ? [] : [6, 4])
        )
    }

    private func drawKeyGrid(context: GraphicsContext) {
        for key in KeyboardLayout.keys where key.character != " " {
            guard let center = calibration.keyCenter(for: key.character) else { continue }
            let mappedCenter = mapped(center)
            let rect = CGRect(x: mappedCenter.x - 10, y: mappedCenter.y - 10, width: 20, height: 20)
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 4),
                with: .color(Color.white.opacity(mode.isCalibrating ? 0.55 : 0.35)),
                lineWidth: 1
            )
            let label = String(key.character).uppercased()
            context.draw(
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(mode.isCalibrating ? 0.9 : 0.65)),
                at: mappedCenter
            )
        }
    }

    private func drawLatestAttribution(context: GraphicsContext) {
        guard case .typing = mode, let result = latestResult else { return }
        guard result.character != " " else { return }
        guard let keyCenter = result.keyCenter else { return }
        let mappedKey = mapped(keyCenter)
        let keyColor: Color = result.isCorrect ? .green : TypingLensTheme.error
        let rect = CGRect(x: mappedKey.x - 14, y: mappedKey.y - 14, width: 28, height: 28)
        context.stroke(Path(ellipseIn: rect), with: .color(keyColor), lineWidth: 3)

        if let detectedFinger = result.detectedFinger,
           let tip = fingertips.first(where: { $0.finger == detectedFinger }) {
            let mappedTip = mapped(tip.position)
            var line = Path()
            line.move(to: mappedTip)
            line.addLine(to: mappedKey)
            context.stroke(line, with: .color(keyColor), lineWidth: 2)
            let tipRect = CGRect(x: mappedTip.x - 6, y: mappedTip.y - 6, width: 12, height: 12)
            context.fill(Path(ellipseIn: tipRect), with: .color(keyColor))
        }
    }
}
