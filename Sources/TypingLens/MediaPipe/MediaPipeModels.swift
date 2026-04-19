import CoreGraphics
import Foundation

struct MediaPipeLandmark: Identifiable, Equatable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let confidence: Float
}

struct MediaPipeStroke: Identifiable, Equatable {
    let id: String
    let points: [CGPoint]
}

struct MediaPipeOverlayState: Equatable {
    var posePoints: [MediaPipeLandmark]
    var poseStrokes: [MediaPipeStroke]
    var handPoints: [MediaPipeLandmark]
    var handStrokes: [MediaPipeStroke]

    static let empty = MediaPipeOverlayState(
        posePoints: [],
        poseStrokes: [],
        handPoints: [],
        handStrokes: []
    )
}

struct MediaPipeCameraFrame {
    let cgImage: CGImage
    let size: CGSize
}

struct MediaPipeViewState {
    var frame: MediaPipeCameraFrame?
    var overlay: MediaPipeOverlayState
    var statusText: String
    var permissionDenied: Bool

    static let initial = MediaPipeViewState(
        frame: nil,
        overlay: .empty,
        statusText: "Starting camera…",
        permissionDenied: false
    )
}
