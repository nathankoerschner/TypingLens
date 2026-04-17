import Foundation
import CoreGraphics

protocol HandTrackingServing {
    var backendName: String { get }
    var isAvailable: Bool { get }
    func track(frame: CapturedFrame) -> TrackedFrame
}

struct UnavailableHandTrackingService: HandTrackingServing {
    let backendName = "MediaPipe"
    let isAvailable = false

    func track(frame: CapturedFrame) -> TrackedFrame {
        TrackedFrame(
            id: frame.frameID,
            timestamp: frame.timestamp,
            imageSize: frame.size,
            fingertips: [],
            backendStatus: "MediaPipe backend unavailable"
        )
    }
}

final class MediaPipeHandTrackingService: HandTrackingServing {
    let backendName = "MediaPipe"
    let isAvailable: Bool

    init(isAvailable: Bool = false) {
        self.isAvailable = isAvailable
    }

    func track(frame: CapturedFrame) -> TrackedFrame {
        guard isAvailable else {
            return TrackedFrame(
                id: frame.frameID,
                timestamp: frame.timestamp,
                imageSize: frame.size,
                fingertips: [],
                backendStatus: "MediaPipe backend unavailable"
            )
        }

        // Placeholder implementation while production MediaPipe wiring is being completed.
        return TrackedFrame(
            id: frame.frameID,
            timestamp: frame.timestamp,
            imageSize: frame.size,
            fingertips: [],
            backendStatus: "MediaPipe backend available"
        )
    }
}
