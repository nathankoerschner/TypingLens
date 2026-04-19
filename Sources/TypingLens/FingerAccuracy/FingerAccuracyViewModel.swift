import CoreGraphics
import Foundation
import Vision

final class FingerAccuracyViewModel: ObservableObject {
    enum Mode: Equatable {
        case calibrating
        case typing

        var isCalibrating: Bool { self == .calibrating }
    }

    static let defaultPromptText = "the quick brown fox jumps over the lazy dog"

    @Published var mode: Mode = .calibrating
    @Published var calibration: KeyboardCalibration = .defaultNormalized
    @Published var swapHands: Bool = false
    @Published private(set) var frame: VisionTrackingCameraFrame?
    @Published private(set) var overlay: VisionTrackingOverlayState = .empty
    @Published private(set) var statusText: String = "Starting camera…"
    @Published private(set) var permissionDenied: Bool = false
    @Published private(set) var results: [AttributionResult] = []
    @Published private(set) var fingertips: [FingertipSample]
    @Published private(set) var promptText: String
    @Published private(set) var currentPromptIndex: Int = 0
    @Published private(set) var promptFeedback: String?
    @Published private(set) var promptFeedbackIsSuccess: Bool = false

    private let cameraController: VisionTrackingCameraControlling
    private let maxResults = 30

    init(
        cameraController: VisionTrackingCameraControlling = VisionTrackingCameraController(runsBodyPose: false),
        promptText: String = FingerAccuracyViewModel.defaultPromptText,
        initialFingertips: [FingertipSample] = []
    ) {
        self.cameraController = cameraController
        self.promptText = promptText
        self.fingertips = initialFingertips

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

    func restartPrompt() {
        currentPromptIndex = 0
        promptFeedback = nil
        promptFeedbackIsSuccess = false
    }

    func handleKeyDown(_ character: Character) {
        guard case .typing = mode else { return }
        let lowered = Self.normalized(character)
        guard let result = makeAttributionResult(for: lowered) else { return }
        results.insert(result, at: 0)
        if results.count > maxResults {
            results.removeLast(results.count - maxResults)
        }

        evaluatePromptProgress(with: lowered, result: result)
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

    var currentPromptCharacter: Character? {
        guard currentPromptIndex < promptText.count else { return nil }
        let index = promptText.index(promptText.startIndex, offsetBy: currentPromptIndex)
        return promptText[index]
    }

    var currentTargetLabel: String {
        guard let currentPromptCharacter else { return "Done" }
        return currentPromptCharacter == " " ? "SPACE" : String(currentPromptCharacter).uppercased()
    }

    var promptProgressLabel: String {
        "\(currentPromptIndex) / \(promptText.count)"
    }

    static func spacebarCenter(for calibration: KeyboardCalibration) -> CGPoint {
        calibration.project(u: 0.5, v: 0.97)
    }

    private func makeAttributionResult(for character: Character) -> AttributionResult? {
        if character == " " {
            let keyCenter = Self.spacebarCenter(for: calibration)
            let attribution = FingerAttributor.attribute(keyCenter: keyCenter, fingertips: fingertips)
            return AttributionResult(
                character: character,
                expectedFinger: .rightThumb,
                acceptedFingers: Set(Finger.allCases),
                detectedFinger: attribution?.finger,
                distance: attribution?.distance,
                keyCenter: keyCenter,
                timestamp: Date()
            )
        }

        guard let key = KeyboardLayout.key(for: character) else { return nil }
        let keyCenter = calibration.keyCenter(for: character)
        let attribution = keyCenter.flatMap {
            FingerAttributor.attribute(
                keyCenter: $0,
                fingertips: fingertips,
                expectedFinger: key.expectedFinger
            )
        }
        return AttributionResult(
            character: character,
            expectedFinger: key.expectedFinger,
            acceptedFingers: Set([key.expectedFinger]),
            detectedFinger: attribution?.finger,
            distance: attribution?.distance,
            keyCenter: keyCenter,
            timestamp: Date()
        )
    }

    private func evaluatePromptProgress(with typedCharacter: Character, result: AttributionResult?) {
        guard let currentPromptCharacter else {
            promptFeedback = "Prompt complete"
            promptFeedbackIsSuccess = true
            return
        }

        guard typedCharacter == currentPromptCharacter else {
            promptFeedback = "Wrong key"
            promptFeedbackIsSuccess = false
            return
        }

        guard let result else {
            promptFeedback = "Unsupported key"
            promptFeedbackIsSuccess = false
            return
        }

        guard result.detectedFinger != nil else {
            promptFeedback = "Track your hands to validate finger choice"
            promptFeedbackIsSuccess = false
            return
        }

        guard result.isCorrect else {
            promptFeedback = "Right key, wrong finger"
            promptFeedbackIsSuccess = false
            return
        }

        currentPromptIndex += 1
        if currentPromptIndex >= promptText.count {
            restartPrompt()
            promptFeedback = "Prompt complete — nice work"
        } else {
            promptFeedback = currentPromptCharacter == " " ? "Right key" : "Right key, right finger"
        }
        promptFeedbackIsSuccess = true
    }

    private static func normalized(_ character: Character) -> Character {
        let lower = String(character).lowercased()
        return lower.first ?? character
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
