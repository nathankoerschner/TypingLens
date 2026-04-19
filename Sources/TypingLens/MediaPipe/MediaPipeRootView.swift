import AppKit
import SwiftUI

struct MediaPipeRootView: View {
    @StateObject private var viewModel: MediaPipeViewModel
    let onClose: () -> Void

    init(viewModel: MediaPipeViewModel = MediaPipeViewModel(), onClose: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MediaPipe")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Native camera capture with live body and hand landmarks")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(TypingLensTheme.subdued)
                }
                Spacer()
                Button("Close", action: onClose)
                    .buttonStyle(TypingLensFilledButtonStyle())
            }

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(TypingLensTheme.panel)

                    if let frame = viewModel.state.frame {
                        MediaPipeFrameView(frame: frame)
                            .clipShape(RoundedRectangle(cornerRadius: 24))

                        MediaPipeOverlayView(overlay: viewModel.state.overlay)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: viewModel.state.permissionDenied ? "camera.slash.fill" : "camera.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(TypingLensTheme.subdued)
                            Text(viewModel.state.statusText)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(TypingLensTheme.text)
                            if viewModel.state.permissionDenied {
                                Button("Retry Camera Access") {
                                    viewModel.requestCameraAccess()
                                }
                                .buttonStyle(TypingLensFilledButtonStyle())
                            }
                        }
                        .padding(24)
                    }

                    VStack {
                        Spacer()
                        HStack {
                            Label("Body", systemImage: "figure.stand")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.35), in: Capsule())
                            Label("Hands", systemImage: "hand.raised.fill")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.35), in: Capsule())
                            Spacer()
                            Text(viewModel.state.statusText)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.35), in: Capsule())
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .padding(20)
        .frame(minWidth: 960, minHeight: 720)
        .background(TypingLensTheme.background)
        .foregroundStyle(TypingLensTheme.text)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

private struct MediaPipeFrameView: View {
    let frame: MediaPipeCameraFrame

    var body: some View {
        Image(decorative: frame.cgImage, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
    }
}

private struct MediaPipeOverlayView: View {
    let overlay: MediaPipeOverlayState

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                func mapped(_ point: CGPoint) -> CGPoint {
                    CGPoint(
                        x: (1 - point.x) * size.width,
                        y: (1 - point.y) * size.height
                    )
                }

                for stroke in overlay.poseStrokes {
                    var path = Path()
                    guard let first = stroke.points.first else { continue }
                    path.move(to: mapped(first))
                    for point in stroke.points.dropFirst() {
                        path.addLine(to: mapped(point))
                    }
                    context.stroke(path, with: .color(Color(nsColor: .systemGreen).opacity(0.95)), lineWidth: 4)
                }

                for stroke in overlay.handStrokes {
                    var path = Path()
                    guard let first = stroke.points.first else { continue }
                    path.move(to: mapped(first))
                    for point in stroke.points.dropFirst() {
                        path.addLine(to: mapped(point))
                    }
                    context.stroke(path, with: .color(Color(nsColor: .systemOrange).opacity(0.95)), lineWidth: 3)
                }

                for point in overlay.posePoints {
                    let center = mapped(CGPoint(x: point.x, y: point.y))
                    let rect = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(nsColor: .systemGreen)))
                }

                for point in overlay.handPoints {
                    let center = mapped(CGPoint(x: point.x, y: point.y))
                    let rect = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(nsColor: .systemOrange)))
                }
            }
        }
    }
}
