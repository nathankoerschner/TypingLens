import Foundation
import XCTest
@testable import TypingLens

final class HandTrackingServiceTests: XCTestCase {
    func testUnavailableServiceEmitsNoFingertipsAndUnavailableStatus() {
        let service = UnavailableHandTrackingService()
        let frame = sampleFrame()

        let tracked = service.track(frame: frame)

        XCTAssertEqual(tracked.id, frame.frameID)
        XCTAssertEqual(tracked.imageSize, frame.size)
        XCTAssertEqual(tracked.fingertips, [])
        XCTAssertEqual(tracked.backendStatus, "MediaPipe backend unavailable")
    }

    func testTrackingServiceConvertsFrameMetadataAndFingerprints() {
        let service = MockHandTrackingService(
            isAvailable: true,
            backendName: "MediaPipe",
            fingertips: [
                TrackedFingertip(id: "left_index", fingerID: "left_index", location: CGPoint(x: 12, y: 34), confidence: 0.9)
            ]
        )
        let frame = sampleFrame()

        let tracked = service.track(frame: frame)

        XCTAssertEqual(tracked.id, frame.frameID)
        XCTAssertEqual(tracked.timestamp, frame.timestamp)
        XCTAssertEqual(tracked.imageSize, frame.size)
        XCTAssertEqual(tracked.fingertips.count, 1)
        XCTAssertEqual(tracked.fingertips.first?.fingerID, "left_index")
        XCTAssertEqual(tracked.backendStatus, "MediaPipe backend available")
    }

    private func sampleFrame() -> CapturedFrame {
        CapturedFrame(
            frameID: 7,
            timestamp: 42.0,
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

private final class MockHandTrackingService: HandTrackingServing {
    let backendName: String
    let isAvailable: Bool
    private let fingertips: [TrackedFingertip]

    init(isAvailable: Bool, backendName: String, fingertips: [TrackedFingertip]) {
        self.isAvailable = isAvailable
        self.backendName = backendName
        self.fingertips = fingertips
    }

    func track(frame: CapturedFrame) -> TrackedFrame {
        TrackedFrame(
            id: frame.frameID,
            timestamp: frame.timestamp,
            imageSize: frame.size,
            fingertips: fingertips,
            backendStatus: isAvailable ? "\(backendName) backend available" : "\(backendName) backend unavailable"
        )
    }
}
