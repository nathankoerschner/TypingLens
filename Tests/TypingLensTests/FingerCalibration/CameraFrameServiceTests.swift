import Foundation
import XCTest
@testable import TypingLens

final class CameraFrameServiceTests: XCTestCase {
    func testFakeServicePublishesFramesAndStopsCallbacksAfterStop() {
        let service = FakeCameraFrameService()
        var frames: [CapturedFrame] = []

        service.onFrame = { frame in
            frames.append(frame)
        }

        let cameras = service.availableCameras()
        XCTAssertEqual(cameras.count, 1)

        XCTAssertNoThrow(try service.start(cameraID: cameras[0].id))
        service.emit(sampleFrame(id: 10, timestamp: 4.0))

        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(service.startCallCount, 1)

        service.stop()
        service.emit(sampleFrame(id: 11, timestamp: 4.1))

        XCTAssertEqual(frames.count, 1)
    }

    func testFakeServiceThrowsWhenCameraIsUnknown() {
        let service = FakeCameraFrameService()

        XCTAssertThrowsError(try service.start(cameraID: "unknown"))
    }

    private func sampleFrame(id: Int64, timestamp: TimeInterval) -> CapturedFrame {
        CapturedFrame(
            frameID: id,
            timestamp: timestamp,
            image: makeTestImage(),
            size: CGSize(width: 100, height: 100)
        )
    }

    private func makeTestImage() -> CGImage {
        let pixelData: [UInt8] = [255, 0, 0, 255]
        let provider = CGDataProvider(data: Data(pixelData) as CFData)!
        return CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).union(.byteOrder32Big),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}

private final class FakeCameraFrameService: CameraFrameServing {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    var onFrame: ((CapturedFrame) -> Void)?
    var isMirroringEnabled = false
    private var isRunning = false
    private var cameras: [CameraOption] = [
        CameraOption(id: "test-camera", displayName: "Test Camera", deviceUniqueID: "device-test")
    ]

    func availableCameras() -> [CameraOption] {
        cameras
    }

    func start(cameraID: String) throws {
        guard cameras.contains(where: { $0.id == cameraID }) else {
            throw CameraFrameServiceError.unknownCamera
        }

        startCallCount += 1
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }

    func emit(_ frame: CapturedFrame) {
        guard isRunning else { return }
        onFrame?(frame)
    }
}
