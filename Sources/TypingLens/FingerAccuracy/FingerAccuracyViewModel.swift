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

    init(cameraController: VisionTrackingCameraControlling = VisionTrackingCameraController(runsBodyPose: false)) {
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
            FingerAttributor.attribute(
                keyCenter: $0,
                fingertips: fingertips,
                expectedFinger: key.expectedFinger
            )
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
        let scored = results.filter { !$0.isUncertain }
        guard !scored.isEmpty else { return nil }
        let correct = scored.reduce(0) { $0 + ($1.isCorrect ? 1 : 0) }
        return Double(correct) / Double(scored.count) * 100
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

        let chiralityByPrefix: [String: VisionTrackingHandedness] = Dictionary(
            uniqueKeysWithValues: overlay.handInfos.map { ($0.prefix, $0.handedness) }
        )

        struct HandGroup {
            let prefix: String
            let averageTipX: Double
            let handedness: VisionTrackingHandedness
            let landmarks: [VisionTrackingLandmark]
        }

        let hands: [HandGroup] = byHand.compactMap { prefix, landmarks in
            let tips = tipBindings.compactMap { suffix, _, _ in
                landmarks.first(where: { $0.id.hasSuffix(suffix) })
            }
            guard !tips.isEmpty else { return nil }
            let averageX = tips.reduce(0) { $0 + Double($1.x) } / Double(tips.count)
            return HandGroup(
                prefix: prefix,
                averageTipX: averageX,
                handedness: chiralityByPrefix[prefix] ?? .unknown,
                landmarks: landmarks
            )
        }.sorted { $0.averageTipX < $1.averageTipX }

        guard !hands.isEmpty else { return [] }

        // Vision's chirality is unreliable on the mirrored front-camera feed — it can
        // report both hands with the same side. Trust it only when it yields a clean
        // one-left / one-right split; otherwise fall back to the centroid heuristic
        // that was already working in the wild.
        let leftCount = hands.filter { $0.handedness == .left }.count
        let rightCount = hands.filter { $0.handedness == .right }.count
        let chiralityIsDecisive = hands.count == 2 && leftCount == 1 && rightCount == 1

        var samples: [FingertipSample] = []
        for (handIndex, hand) in hands.enumerated() {
            let inferredIsLeftHand: Bool
            if chiralityIsDecisive {
                inferredIsLeftHand = hand.handedness == .left
            } else if hands.count == 1 {
                // Single hand: prefer chirality when known, otherwise use position.
                // Vision X is mirrored on the preview (1 - x), so higher Vision X = visually left.
                switch hand.handedness {
                case .left: inferredIsLeftHand = true
                case .right: inferredIsLeftHand = false
                case .unknown: inferredIsLeftHand = hand.averageTipX >= 0.5
                }
            } else {
                // Two hands, chirality not decisive — original position-sort behavior.
                inferredIsLeftHand = (handIndex == hands.count - 1)
            }
            let isLeftHand = swapHands ? !inferredIsLeftHand : inferredIsLeftHand

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
