import CoreGraphics
import Foundation

struct VisionTrackingLandmark: Identifiable, Equatable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let confidence: Float
}

struct VisionTrackingStroke: Identifiable, Equatable {
    let id: String
    let points: [CGPoint]
}

struct VisionTrackingOverlayState: Equatable {
    var posePoints: [VisionTrackingLandmark]
    var poseStrokes: [VisionTrackingStroke]
    var handPoints: [VisionTrackingLandmark]
    var handStrokes: [VisionTrackingStroke]

    static let empty = VisionTrackingOverlayState(
        posePoints: [],
        poseStrokes: [],
        handPoints: [],
        handStrokes: []
    )
}

struct VisionTrackingCameraFrame {
    let cgImage: CGImage
    let size: CGSize
}

struct VisionTrackingViewState {
    var frame: VisionTrackingCameraFrame?
    var overlay: VisionTrackingOverlayState
    var statusText: String
    var permissionDenied: Bool

    static let initial = VisionTrackingViewState(
        frame: nil,
        overlay: .empty,
        statusText: "Starting camera…",
        permissionDenied: false
    )
}
