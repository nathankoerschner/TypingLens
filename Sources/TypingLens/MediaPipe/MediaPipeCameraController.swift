import AVFoundation
import AppKit
import CoreImage
import Foundation
import ImageIO
import QuartzCore
import Vision

final class MediaPipeViewModel: ObservableObject {
    @Published private(set) var state: MediaPipeViewState = .initial

    private let cameraController: MediaPipeCameraControlling

    init(cameraController: MediaPipeCameraControlling = MediaPipeCameraController()) {
        self.cameraController = cameraController
        cameraController.onFrameUpdate = { [weak self] frame, overlay in
            guard let self else { return }
            self.state.frame = frame
            self.state.overlay = overlay
            self.state.statusText = "Live body + hand landmarks"
            self.state.permissionDenied = false
        }
        cameraController.onStatusUpdate = { [weak self] status, permissionDenied in
            guard let self else { return }
            self.state.statusText = status
            self.state.permissionDenied = permissionDenied
        }
    }

    func start() {
        cameraController.start()
    }

    func stop() {
        cameraController.stop()
    }

    func requestCameraAccess() {
        cameraController.requestCameraAccess()
    }
}

protocol MediaPipeCameraControlling: AnyObject {
    var onFrameUpdate: ((MediaPipeCameraFrame, MediaPipeOverlayState) -> Void)? { get set }
    var onStatusUpdate: ((String, Bool) -> Void)? { get set }
    func start()
    func stop()
    func requestCameraAccess()
}

final class MediaPipeCameraController: NSObject, MediaPipeCameraControlling {
    var onFrameUpdate: ((MediaPipeCameraFrame, MediaPipeOverlayState) -> Void)?
    var onStatusUpdate: ((String, Bool) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "typinglens.mediapipe.session")
    private let visionQueue = DispatchQueue(label: "typinglens.mediapipe.vision")
    private let sequenceHandler = VNSequenceRequestHandler()
    private let ciContext = CIContext(options: nil)
    private var isConfigured = false
    private var isRunning = false
    private var isProcessingFrame = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartIfNeeded()
        case .notDetermined:
            onStatusUpdate?("Requesting camera access…", false)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureAndStartIfNeeded()
                    } else {
                        self.onStatusUpdate?("Camera access is required to use MediaPipe.", true)
                    }
                }
            }
        default:
            onStatusUpdate?("Camera access is required to use MediaPipe.", true)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isRunning else { return }
            self.session.stopRunning()
            self.isRunning = false
        }
    }

    func requestCameraAccess() {
        start()
    }

    private func configureAndStartIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                do {
                    try self.configureSession()
                    self.isConfigured = true
                } catch {
                    DispatchQueue.main.async {
                        self.onStatusUpdate?("Failed to configure camera: \(error.localizedDescription)", false)
                    }
                    return
                }
            }

            guard !self.isRunning else { return }
            self.session.startRunning()
            self.isRunning = true
            DispatchQueue.main.async {
                self.onStatusUpdate?("Camera running…", false)
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = preferredCameraDevice() else {
            throw NSError(domain: "MediaPipeCameraController", code: -1, userInfo: [NSLocalizedDescriptionKey: "No camera device found"])
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "MediaPipeCameraController", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to attach camera input"])
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: visionQueue)

        guard session.canAddOutput(output) else {
            throw NSError(domain: "MediaPipeCameraController", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to attach camera output"])
        }
        session.addOutput(output)
        output.connection(with: .video)?.isVideoMirrored = true

        session.commitConfiguration()
    }

    private func preferredCameraDevice() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.builtInWideAngleCamera, .external, .continuityCamera]
        } else {
            deviceTypes = [.builtInWideAngleCamera]
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first
    }
}

extension MediaPipeCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessingFrame else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        isProcessingFrame = true

        let orientation: CGImagePropertyOrientation = connection.isVideoMirrored ? .upMirrored : .up
        let requestTime = CACurrentMediaTime()

        let poseRequest = VNDetectHumanBodyPoseRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2

        do {
            try sequenceHandler.perform([poseRequest, handRequest], on: pixelBuffer, orientation: orientation)

            let overlay = Self.makeOverlay(
                poseObservations: poseRequest.results ?? [],
                handObservations: handRequest.results ?? []
            )
            guard let frame = makeFrame(from: pixelBuffer) else {
                isProcessingFrame = false
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.onFrameUpdate?(frame, overlay)
                let elapsedMs = Int((CACurrentMediaTime() - requestTime) * 1000)
                self?.onStatusUpdate?("Live body + hand landmarks • \(elapsedMs) ms", false)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onStatusUpdate?("Vision inference failed: \(error.localizedDescription)", false)
            }
        }

        isProcessingFrame = false
    }

    private func makeFrame(from pixelBuffer: CVPixelBuffer) -> MediaPipeCameraFrame? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let rect = CGRect(origin: .zero, size: CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)))
        guard let cgImage = ciContext.createCGImage(image, from: rect) else {
            return nil
        }
        return MediaPipeCameraFrame(cgImage: cgImage, size: rect.size)
    }

    private static func makeOverlay(
        poseObservations: [VNHumanBodyPoseObservation],
        handObservations: [VNHumanHandPoseObservation]
    ) -> MediaPipeOverlayState {
        var posePoints: [MediaPipeLandmark] = []
        var poseStrokes: [MediaPipeStroke] = []
        var handPoints: [MediaPipeLandmark] = []
        var handStrokes: [MediaPipeStroke] = []

        for (index, observation) in poseObservations.enumerated() {
            if let result = makePoseLandmarks(from: observation, prefix: "pose-\(index)") {
                posePoints.append(contentsOf: result.points)
                poseStrokes.append(contentsOf: result.strokes)
            }
        }

        for (index, observation) in handObservations.enumerated() {
            if let result = makeHandLandmarks(from: observation, prefix: "hand-\(index)") {
                handPoints.append(contentsOf: result.points)
                handStrokes.append(contentsOf: result.strokes)
            }
        }

        return MediaPipeOverlayState(
            posePoints: posePoints,
            poseStrokes: poseStrokes,
            handPoints: handPoints,
            handStrokes: handStrokes
        )
    }

    private static func makePoseLandmarks(
        from observation: VNHumanBodyPoseObservation,
        prefix: String
    ) -> (points: [MediaPipeLandmark], strokes: [MediaPipeStroke])? {
        let joints: [VNHumanBodyPoseObservation.JointName] = [
            .nose,
            .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .root,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        let recognized = try? observation.recognizedPoints(.all)
        guard let recognized else { return nil }

        let points = joints.compactMap { joint -> MediaPipeLandmark? in
            guard let point = recognized[joint], point.confidence > 0.15 else { return nil }
            return MediaPipeLandmark(
                id: "\(prefix)-\(joint.rawValue)",
                x: CGFloat(point.location.x),
                y: CGFloat(point.location.y),
                confidence: point.confidence
            )
        }

        let pointMap = Dictionary(uniqueKeysWithValues: points.compactMap { point in
            joints.first(where: { "\(prefix)-\($0.rawValue)" == point.id }).map { ($0.rawValue, point) }
        })
        let connections: [[VNHumanBodyPoseObservation.JointName]] = [
            [.nose, .neck],
            [.neck, .leftShoulder],
            [.leftShoulder, .leftElbow],
            [.leftElbow, .leftWrist],
            [.neck, .rightShoulder],
            [.rightShoulder, .rightElbow],
            [.rightElbow, .rightWrist],
            [.leftShoulder, .root],
            [.rightShoulder, .root],
            [.root, .leftHip],
            [.leftHip, .leftKnee],
            [.leftKnee, .leftAnkle],
            [.root, .rightHip],
            [.rightHip, .rightKnee],
            [.rightKnee, .rightAnkle],
            [.leftHip, .rightHip]
        ]

        let strokes = connections.compactMap { pair -> MediaPipeStroke? in
            let startName = pair[0].rawValue
            let endName = pair[1].rawValue
            guard
                let start = pointMap[startName],
                let end = pointMap[endName]
            else {
                return nil
            }
            return MediaPipeStroke(
                id: "\(prefix)-\(startName)-\(endName)",
                points: [CGPoint(x: start.x, y: start.y), CGPoint(x: end.x, y: end.y)]
            )
        }

        return (points, strokes)
    }

    private static func makeHandLandmarks(
        from observation: VNHumanHandPoseObservation,
        prefix: String
    ) -> (points: [MediaPipeLandmark], strokes: [MediaPipeStroke])? {
        let joints: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        let recognized = try? observation.recognizedPoints(.all)
        guard let recognized else { return nil }

        let points = joints.compactMap { joint -> MediaPipeLandmark? in
            guard let point = recognized[joint], point.confidence > 0.15 else { return nil }
            return MediaPipeLandmark(
                id: "\(prefix)-\(joint.rawValue)",
                x: CGFloat(point.location.x),
                y: CGFloat(point.location.y),
                confidence: point.confidence
            )
        }

        let pointMap = Dictionary(uniqueKeysWithValues: points.compactMap { point in
            joints.first(where: { "\(prefix)-\($0.rawValue)" == point.id }).map { ($0.rawValue, point) }
        })
        let fingers: [[VNHumanHandPoseObservation.JointName]] = [
            [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
            [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
            [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
            [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
            [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip]
        ]

        let strokes = fingers.flatMap { finger -> [MediaPipeStroke] in
            zip(finger, finger.dropFirst()).compactMap { startJoint, endJoint in
                let startName = startJoint.rawValue
                let endName = endJoint.rawValue
                guard
                    let start = pointMap[startName],
                    let end = pointMap[endName]
                else {
                    return nil
                }
                return MediaPipeStroke(
                    id: "\(prefix)-\(startName)-\(endName)",
                    points: [CGPoint(x: start.x, y: start.y), CGPoint(x: end.x, y: end.y)]
                )
            }
        }

        return (points, strokes)
    }
}
