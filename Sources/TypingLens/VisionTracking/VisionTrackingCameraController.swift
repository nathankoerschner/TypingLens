import AVFoundation
import AppKit
import CoreImage
import Foundation
import ImageIO
import QuartzCore
import Vision

final class VisionTrackingViewModel: ObservableObject {
    @Published private(set) var state: VisionTrackingViewState = .initial

    private let cameraController: VisionTrackingCameraControlling

    init(cameraController: VisionTrackingCameraControlling = VisionTrackingCameraController()) {
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

protocol VisionTrackingCameraControlling: AnyObject {
    var onFrameUpdate: ((VisionTrackingCameraFrame, VisionTrackingOverlayState) -> Void)? { get set }
    var onStatusUpdate: ((String, Bool) -> Void)? { get set }
    func start()
    func stop()
    func requestCameraAccess()
}

final class VisionTrackingCameraController: NSObject, VisionTrackingCameraControlling {
    var onFrameUpdate: ((VisionTrackingCameraFrame, VisionTrackingOverlayState) -> Void)?
    var onStatusUpdate: ((String, Bool) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "typinglens.visiontracking.session")
    private let visionQueue = DispatchQueue(label: "typinglens.visiontracking.vision")
    private let sequenceHandler = VNSequenceRequestHandler()
    private let ciContext = CIContext(options: nil)
    private let runsBodyPose: Bool
    private var isConfigured = false
    private var isRunning = false
    private var isProcessingFrame = false

    init(runsBodyPose: Bool = true) {
        self.runsBodyPose = runsBodyPose
        super.init()
    }

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
                        self.onStatusUpdate?("Camera access is required to use VisionTracking.", true)
                    }
                }
            }
        default:
            onStatusUpdate?("Camera access is required to use VisionTracking.", true)
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
            throw NSError(domain: "VisionTrackingCameraController", code: -1, userInfo: [NSLocalizedDescriptionKey: "No camera device found"])
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "VisionTrackingCameraController", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to attach camera input"])
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: visionQueue)

        guard session.canAddOutput(output) else {
            throw NSError(domain: "VisionTrackingCameraController", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to attach camera output"])
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

extension VisionTrackingCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessingFrame else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        isProcessingFrame = true

        let orientation: CGImagePropertyOrientation = connection.isVideoMirrored ? .upMirrored : .up
        let requestTime = CACurrentMediaTime()

        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2

        var requests: [VNRequest] = []
        let poseRequest: VNDetectHumanBodyPoseRequest?
        if runsBodyPose {
            let request = VNDetectHumanBodyPoseRequest()
            requests.append(request)
            poseRequest = request
        } else {
            poseRequest = nil
        }
        requests.append(handRequest)

        do {
            try sequenceHandler.perform(requests, on: pixelBuffer, orientation: orientation)

            let overlay = Self.makeOverlay(
                poseObservations: poseRequest?.results ?? [],
                handObservations: handRequest.results ?? []
            )
            guard let frame = makeFrame(from: pixelBuffer) else {
                isProcessingFrame = false
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.onFrameUpdate?(frame, overlay)
                let elapsedMs = Int((CACurrentMediaTime() - requestTime) * 1000)
                let summary = self?.runsBodyPose == false ? "Live hand landmarks" : "Live body + hand landmarks"
                self?.onStatusUpdate?("\(summary) • \(elapsedMs) ms", false)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onStatusUpdate?("Vision inference failed: \(error.localizedDescription)", false)
            }
        }

        isProcessingFrame = false
    }

    private func makeFrame(from pixelBuffer: CVPixelBuffer) -> VisionTrackingCameraFrame? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let rect = CGRect(origin: .zero, size: CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)))
        guard let cgImage = ciContext.createCGImage(image, from: rect) else {
            return nil
        }
        return VisionTrackingCameraFrame(cgImage: cgImage, size: rect.size)
    }

    private static func makeOverlay(
        poseObservations: [VNHumanBodyPoseObservation],
        handObservations: [VNHumanHandPoseObservation]
    ) -> VisionTrackingOverlayState {
        var posePoints: [VisionTrackingLandmark] = []
        var poseStrokes: [VisionTrackingStroke] = []
        var handPoints: [VisionTrackingLandmark] = []
        var handStrokes: [VisionTrackingStroke] = []
        var handInfos: [VisionTrackingHandInfo] = []

        for (index, observation) in poseObservations.enumerated() {
            if let result = makePoseLandmarks(from: observation, prefix: "pose-\(index)") {
                posePoints.append(contentsOf: result.points)
                poseStrokes.append(contentsOf: result.strokes)
            }
        }

        for (index, observation) in handObservations.enumerated() {
            let prefix = "hand-\(index)"
            if let result = makeHandLandmarks(from: observation, prefix: prefix) {
                handPoints.append(contentsOf: result.points)
                handStrokes.append(contentsOf: result.strokes)
                handInfos.append(VisionTrackingHandInfo(
                    prefix: prefix,
                    handedness: handedness(from: observation.chirality)
                ))
            }
        }

        return VisionTrackingOverlayState(
            posePoints: posePoints,
            poseStrokes: poseStrokes,
            handPoints: handPoints,
            handStrokes: handStrokes,
            handInfos: handInfos
        )
    }

    private static func handedness(from chirality: VNChirality) -> VisionTrackingHandedness {
        switch chirality {
        case .left: return .left
        case .right: return .right
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }

    private static func makePoseLandmarks(
        from observation: VNHumanBodyPoseObservation,
        prefix: String
    ) -> (points: [VisionTrackingLandmark], strokes: [VisionTrackingStroke])? {
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

        let points = joints.compactMap { joint -> VisionTrackingLandmark? in
            guard let point = recognized[joint], point.confidence > 0.15 else { return nil }
            return VisionTrackingLandmark(
                id: "\(prefix)-\(joint.rawValue.rawValue)",
                x: CGFloat(point.location.x),
                y: CGFloat(point.location.y),
                confidence: point.confidence
            )
        }

        let pointMap = Dictionary(uniqueKeysWithValues: points.compactMap { point in
            joints.first(where: { "\(prefix)-\($0.rawValue.rawValue)" == point.id }).map { ($0.rawValue, point) }
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

        let strokes = connections.compactMap { pair -> VisionTrackingStroke? in
            let startName = pair[0].rawValue
            let endName = pair[1].rawValue
            guard
                let start = pointMap[startName],
                let end = pointMap[endName]
            else {
                return nil
            }
            return VisionTrackingStroke(
                id: "\(prefix)-\(startName)-\(endName)",
                points: [CGPoint(x: start.x, y: start.y), CGPoint(x: end.x, y: end.y)]
            )
        }

        return (points, strokes)
    }

    private static func makeHandLandmarks(
        from observation: VNHumanHandPoseObservation,
        prefix: String
    ) -> (points: [VisionTrackingLandmark], strokes: [VisionTrackingStroke])? {
        let joints: [VNHumanHandPoseObservation.JointName] = [
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        let recognized = try? observation.recognizedPoints(.all)
        guard let recognized else { return nil }

        let points = joints.compactMap { joint -> VisionTrackingLandmark? in
            guard let point = recognized[joint], point.confidence > 0.15 else { return nil }
            return VisionTrackingLandmark(
                id: "\(prefix)-\(joint.rawValue.rawValue)",
                x: CGFloat(point.location.x),
                y: CGFloat(point.location.y),
                confidence: point.confidence
            )
        }

        let pointMap = Dictionary(uniqueKeysWithValues: points.compactMap { point in
            joints.first(where: { "\(prefix)-\($0.rawValue.rawValue)" == point.id }).map { ($0.rawValue, point) }
        })
        let fingers: [[VNHumanHandPoseObservation.JointName]] = [
            [.thumbCMC, .thumbMP, .thumbIP, .thumbTip],
            [.indexMCP, .indexPIP, .indexDIP, .indexTip],
            [.middleMCP, .middlePIP, .middleDIP, .middleTip],
            [.ringMCP, .ringPIP, .ringDIP, .ringTip],
            [.littleMCP, .littlePIP, .littleDIP, .littleTip]
        ]

        let strokes = fingers.flatMap { finger -> [VisionTrackingStroke] in
            zip(finger, finger.dropFirst()).compactMap { startJoint, endJoint in
                let startName = startJoint.rawValue
                let endName = endJoint.rawValue
                guard
                    let start = pointMap[startName],
                    let end = pointMap[endName]
                else {
                    return nil
                }
                return VisionTrackingStroke(
                    id: "\(prefix)-\(startName)-\(endName)",
                    points: [CGPoint(x: start.x, y: start.y), CGPoint(x: end.x, y: end.y)]
                )
            }
        }

        return (points, strokes)
    }
}
