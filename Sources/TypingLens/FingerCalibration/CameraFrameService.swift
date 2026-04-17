import Foundation
import AVFoundation
import CoreGraphics
import CoreImage

enum CameraFrameServiceError: Error, Equatable {
    case unknownCamera
    case startupFailed
}

protocol CameraFrameServing: AnyObject {
    func availableCameras() -> [CameraOption]
    func start(cameraID: String) throws
    func stop()
    var onFrame: ((CapturedFrame) -> Void)? { get set }
    var isMirroringEnabled: Bool { get set }
}

final class AVFoundationCameraFrameService: NSObject, CameraFrameServing {
    var onFrame: ((CapturedFrame) -> Void)?
    var isMirroringEnabled = false

    private let captureSession: AVCaptureSession
    private let videoOutput: AVCaptureVideoDataOutput
    private let captureQueue: DispatchQueue
    private let outputQueue = DispatchQueue(label: "com.typinglens.cameraframe.output")
    private let ciContext: CIContext
    private var frameID: Int64 = 0
    private var currentInput: AVCaptureDeviceInput?

    override init() {
        captureSession = AVCaptureSession()
        videoOutput = AVCaptureVideoDataOutput()
        captureQueue = DispatchQueue(label: "com.typinglens.cameraframe.capture")
        ciContext = CIContext()
        super.init()
    }

    func availableCameras() -> [CameraOption] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )

        return discovery.devices
            .map {
                CameraOption(id: $0.uniqueID, displayName: $0.localizedName, deviceUniqueID: $0.uniqueID)
            }
            .sorted { first, second in
                first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
            }
    }

    func start(cameraID: String) throws {
        stop()

        guard let camera = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.first(where: { $0.uniqueID == cameraID }) else {
            throw CameraFrameServiceError.unknownCamera
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .high

            captureSession.inputs.forEach { captureSession.removeInput($0) }
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                captureSession.commitConfiguration()
                throw CameraFrameServiceError.startupFailed
            }
            currentInput = input

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

            captureSession.outputs.forEach { captureSession.removeOutput($0) }
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            } else {
                captureSession.commitConfiguration()
                throw CameraFrameServiceError.startupFailed
            }

            videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
            captureSession.commitConfiguration()
            captureSession.startRunning()
        } catch {
            captureSession.commitConfiguration()
            throw CameraFrameServiceError.startupFailed
        }
    }

    func stop() {
        guard captureSession.isRunning else {
            return
        }

        captureSession.stopRunning()
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        currentInput = nil
        frameID = 0
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
    }
}

extension AVFoundationCameraFrameService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        var ciImage = CIImage(cvImageBuffer: imageBuffer)
        if isMirroringEnabled {
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -ciImage.extent.width, y: 0))
        }

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        frameID += 1

        let frame = CapturedFrame(
            frameID: frameID,
            timestamp: ProcessInfo.processInfo.systemUptime,
            image: cgImage,
            size: CGSize(width: CGFloat(CVPixelBufferGetWidth(imageBuffer)), height: CGFloat(CVPixelBufferGetHeight(imageBuffer)))
        )

        outputQueue.async { [weak self] in
            guard let onFrame = self?.onFrame else { return }
            onFrame(frame)
        }
    }
}
