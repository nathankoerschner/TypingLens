import AppKit
import SwiftUI

struct VisionTrackingRootView: View {
    @StateObject private var viewModel: VisionTrackingViewModel
    let onClose: () -> Void

    init(viewModel: VisionTrackingViewModel = VisionTrackingViewModel(), onClose: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("VisionTracking")
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
                let imageRect = Self.imageDisplayRect(
                    imageSize: viewModel.state.frame?.size,
                    in: proxy.size
                )
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(TypingLensTheme.panel)

                    if let frame = viewModel.state.frame {
                        VisionTrackingFrameView(frame: frame)
                            .clipShape(RoundedRectangle(cornerRadius: 24))

                        VisionTrackingOverlayView(overlay: viewModel.state.overlay, imageRect: imageRect)
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
}

private struct VisionTrackingFrameView: View {
    let frame: VisionTrackingCameraFrame

    var body: some View {
        Image(decorative: frame.cgImage, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

private struct VisionTrackingOverlayView: View {
    let overlay: VisionTrackingOverlayState
    let imageRect: CGRect

    var body: some View {
        Canvas { context, _ in
            func mapped(_ point: CGPoint) -> CGPoint {
                CGPoint(
                    x: imageRect.minX + (1 - point.x) * imageRect.width,
                    y: imageRect.minY + (1 - point.y) * imageRect.height
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
