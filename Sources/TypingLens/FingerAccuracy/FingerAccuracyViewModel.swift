import CoreGraphics
import Foundation
import Vision

final class FingerAccuracyViewModel: ObservableObject {
    enum Mode: Equatable {
        case calibrating
        case typing

        var isCalibrating: Bool { self == .calibrating }
    }

    @Published var mode: Mode = .calibrating
    @Published var calibration: KeyboardCalibration = .defaultNormalized
    @Published var swapHands: Bool = false
    @Published private(set) var frame: VisionTrackingCameraFrame?
    @Published private(set) var overlay: VisionTrackingOverlayState = .empty
    @Published private(set) var statusText: String = "Starting camera…"
    @Published private(set) var permissionDenied: Bool = false
    @Published private(set) var results: [AttributionResult] = []
    @Published private(set) var fingertips: [FingertipSample] = []

    private let cameraController: VisionTrackingCameraControlling
    private let maxResults = 30

    init(cameraController: VisionTrackingCameraControlling = VisionTrackingCameraController()) {
        self.cameraController = cameraController
        cameraController.onFrameUpdate = { [weak self] frame, overlay in
            guard let self else { return }
            self.frame = frame
            self.overlay = overlay
            self.fingertips = Self.extractFingertips(from: overlay, swapHands: self.swapHands)
        }
        cameraController.onStatusUpdate = { [weak self] status, denied in
            guard let self else { return }
            self.statusText = status
            self.permissionDenied = denied
        }
    }

    func start() { cameraController.start() }
    func stop() { cameraController.stop() }
    func requestCameraAccess() { cameraController.requestCameraAccess() }

    func beginCalibration() {
        mode = .calibrating
    }

    func finishCalibration() {
        mode = .typing
    }

    func setCorner(_ corner: CalibrationCorner, to visionPoint: CGPoint) {
        let clamped = CGPoint(
            x: min(max(visionPoint.x, 0), 1),
            y: min(max(visionPoint.y, 0), 1)
        )
        calibration.setCorner(corner, to: clamped)
    }

    func resetCalibration() {
        calibration = .defaultNormalized
    }

    func handleKeyDown(_ character: Character) {
        guard case .typing = mode else { return }
        let lowered: Character = {
            let lower = String(character).lowercased()
            return lower.first ?? character
        }()
        guard let key = KeyboardLayout.key(for: lowered) else { return }
        let keyCenter = calibration.keyCenter(for: lowered)
        let attribution = keyCenter.flatMap {
            FingerAttributor.attribute(keyCenter: $0, fingertips: fingertips)
        }
        let result = AttributionResult(
            character: lowered,
            expectedFinger: key.expectedFinger,
            detectedFinger: attribution?.finger,
            distance: attribution?.distance,
            keyCenter: keyCenter,
            timestamp: Date()
        )
        results.insert(result, at: 0)
        if results.count > maxResults {
            results.removeLast(results.count - maxResults)
        }
    }

    func clearResults() {
        results.removeAll()
    }

    func toggleSwapHands() {
        swapHands.toggle()
        fingertips = Self.extractFingertips(from: overlay, swapHands: swapHands)
    }

    var accuracyPercent: Double? {
        guard !results.isEmpty else { return nil }
        let correct = results.reduce(0) { $0 + ($1.isCorrect ? 1 : 0) }
        return Double(correct) / Double(results.count) * 100
    }

    private static let tipBindings: [(suffix: String, leftFinger: Finger, rightFinger: Finger)] = [
        ("-" + VNHumanHandPoseObservation.JointName.thumbTip.rawValue.rawValue, .leftThumb, .rightThumb),
        ("-" + VNHumanHandPoseObservation.JointName.indexTip.rawValue.rawValue, .leftIndex, .rightIndex),
        ("-" + VNHumanHandPoseObservation.JointName.middleTip.rawValue.rawValue, .leftMiddle, .rightMiddle),
        ("-" + VNHumanHandPoseObservation.JointName.ringTip.rawValue.rawValue, .leftRing, .rightRing),
        ("-" + VNHumanHandPoseObservation.JointName.littleTip.rawValue.rawValue, .leftPinky, .rightPinky)
    ]

    static func extractFingertips(
        from overlay: VisionTrackingOverlayState,
        swapHands: Bool
    ) -> [FingertipSample] {
        var byHand: [String: [VisionTrackingLandmark]] = [:]
        for landmark in overlay.handPoints {
            let parts = landmark.id.split(separator: "-", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count >= 2 else { continue }
            let handKey = "\(parts[0])-\(parts[1])"
            byHand[handKey, default: []].append(landmark)
        }

        let hands: [(x: Double, landmarks: [VisionTrackingLandmark])] = byHand.values.compactMap { landmarks in
            let tips = tipBindings.compactMap { suffix, _, _ in
                landmarks.first(where: { $0.id.hasSuffix(suffix) })
            }
            guard !tips.isEmpty else { return nil }
            let averageX = tips.reduce(0) { $0 + Double($1.x) } / Double(tips.count)
            return (averageX, landmarks)
        }.sorted { $0.x < $1.x }

        guard !hands.isEmpty else { return [] }

        var samples: [FingertipSample] = []
        for (handIndex, hand) in hands.enumerated() {
            let isLeftHand: Bool
            if hands.count == 1 {
                // The preview maps Vision X with `1 - x`, so larger Vision X appears on the left side of the screen.
                let inferredIsLeftHand = hand.x >= 0.5
                isLeftHand = swapHands ? !inferredIsLeftHand : inferredIsLeftHand
            } else {
                let defaultIsLeft = (handIndex == hands.count - 1)
                isLeftHand = swapHands ? !defaultIsLeft : defaultIsLeft
            }
            for (suffix, leftFinger, rightFinger) in tipBindings {
                guard let tip = hand.landmarks.first(where: { $0.id.hasSuffix(suffix) }) else { continue }
                let finger = isLeftHand ? leftFinger : rightFinger
                samples.append(FingertipSample(
                    finger: finger,
                    position: CGPoint(x: tip.x, y: tip.y),
                    confidence: Double(tip.confidence)
                ))
            }
        }
        return samples
    }
}
