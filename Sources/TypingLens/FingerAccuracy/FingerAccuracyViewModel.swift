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
    @Published private(set) var contactObservations: [FingerAccuracyKeyContactObservation] = []

    private let cameraController: VisionTrackingCameraControlling
    private let keyboardContactEstimator = FingerAccuracyKeyboardContactEstimator()
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
            self.keyboardContactEstimator.ingest(frame: frame, calibration: self.calibration)
            self.frame = frame
            self.overlay = overlay
            self.fingertips = Self.extractFingertips(from: overlay, swapHands: self.swapHands)
            self.contactObservations = Self.sortedContactObservations(self.keyboardContactEstimator.latestObservations)
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

    static func keyToken(for character: Character) -> String? {
        if character == " " {
            return "space"
        }
        guard KeyboardLayout.key(for: character) != nil else { return nil }
        return String(character).lowercased()
    }

    private func makeAttributionResult(for character: Character) -> AttributionResult? {
        let keyToken = Self.keyToken(for: character)
        let contactObservation = keyToken.flatMap { keyboardContactEstimator.observation(for: $0) }
        let contactCentroid = contactObservation?.contactCentroid.map(Self.displayToVision)
        let contactWeight = contactObservation?.contactLikelihood ?? 0

        if character == " " {
            let keyCenter = Self.spacebarCenter(for: calibration)
            let attribution = FingerAttributor.attribute(
                keyCenter: keyCenter,
                fingertips: fingertips,
                contactCentroid: contactCentroid,
                contactWeight: contactWeight
            )
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
                expectedFinger: key.expectedFinger,
                contactCentroid: contactCentroid,
                contactWeight: contactWeight
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

    private static func displayToVision(_ point: CGPoint) -> CGPoint {
        CGPoint(x: 1 - point.x, y: 1 - point.y)
    }

    private static func sortedContactObservations(
        _ observations: [String: FingerAccuracyKeyContactObservation]
    ) -> [FingerAccuracyKeyContactObservation] {
        observations.values.sorted { lhs, rhs in
            if lhs.contactLikelihood == rhs.contactLikelihood {
                return lhs.keyToken < rhs.keyToken
            }
            return lhs.contactLikelihood > rhs.contactLikelihood
        }
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

struct FingerAccuracyKeyContactObservation: Identifiable, Equatable {
    let keyToken: String
    let contactLikelihood: CGFloat
    let motionEnergy: CGFloat
    let occlusionEnergy: CGFloat
    let contactCentroid: CGPoint?

    var id: String { keyToken }
}

private struct FingerAccuracyKeyRegion {
    let keyToken: String
    let displayCenter: CGPoint
    let normalizedSize: CGSize
}

private final class FingerAccuracyKeyboardContactEstimator {
    private struct LumaFrame {
        let width: Int
        let height: Int
        let pixels: [UInt8]
    }

    private let sampleWidth = 160
    private let sampleHeight = 120
    private let stableMotionThreshold: Float = 6
    private let motionFloor: Float = 4
    private let occlusionFloor: Float = 10

    private var previousFrame: LumaFrame?
    private var baselinePixels: [Float]?

    private(set) var latestObservations: [String: FingerAccuracyKeyContactObservation] = [:]

    func ingest(frame: VisionTrackingCameraFrame, calibration: KeyboardCalibration) {
        guard let currentFrame = makeLumaFrame(from: frame.cgImage) else { return }

        if baselinePixels == nil {
            baselinePixels = currentFrame.pixels.map(Float.init)
        }

        guard let previousFrame, var baselinePixels else {
            self.previousFrame = currentFrame
            latestObservations = [:]
            return
        }

        let keyRegions = Self.keyRegions(for: calibration)
        var observations: [String: FingerAccuracyKeyContactObservation] = [:]
        for region in keyRegions {
            observations[region.keyToken] = makeObservation(
                for: region,
                currentFrame: currentFrame,
                previousFrame: previousFrame,
                baselinePixels: baselinePixels
            )
        }

        let alpha: Float = 0.04
        for index in currentFrame.pixels.indices {
            let current = Float(currentFrame.pixels[index])
            let previous = Float(previousFrame.pixels[index])
            let motion = abs(current - previous)
            if motion <= stableMotionThreshold {
                baselinePixels[index] = ((1 - alpha) * baselinePixels[index]) + (alpha * current)
            }
        }

        self.baselinePixels = baselinePixels
        self.previousFrame = currentFrame
        latestObservations = observations
    }

    func observation(for keyToken: String) -> FingerAccuracyKeyContactObservation? {
        latestObservations[keyToken]
    }

    private func makeObservation(
        for region: FingerAccuracyKeyRegion,
        currentFrame: LumaFrame,
        previousFrame: LumaFrame,
        baselinePixels: [Float]
    ) -> FingerAccuracyKeyContactObservation {
        let rect = pixelRect(for: region, in: currentFrame)
        let minX = max(Int(rect.minX.rounded(.down)), 0)
        let maxX = min(Int(rect.maxX.rounded(.up)), currentFrame.width - 1)
        let minY = max(Int(rect.minY.rounded(.down)), 0)
        let maxY = min(Int(rect.maxY.rounded(.up)), currentFrame.height - 1)

        guard minX <= maxX, minY <= maxY else {
            return FingerAccuracyKeyContactObservation(
                keyToken: region.keyToken,
                contactLikelihood: 0,
                motionEnergy: 0,
                occlusionEnergy: 0,
                contactCentroid: nil
            )
        }

        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        var weightSum: CGFloat = 0
        var motionSum: Float = 0
        var occlusionSum: Float = 0
        var area = 0

        for y in minY...maxY {
            for x in minX...maxX {
                let index = (y * currentFrame.width) + x
                let current = Float(currentFrame.pixels[index])
                let previous = Float(previousFrame.pixels[index])
                let baseline = baselinePixels[index]

                let motion = max(0, abs(current - previous) - motionFloor)
                let occlusion = max(0, abs(current - baseline) - occlusionFloor)
                let weight = CGFloat((0.65 * occlusion) + (0.35 * motion))

                weightedX += (CGFloat(x) + 0.5) * weight
                weightedY += (CGFloat(y) + 0.5) * weight
                weightSum += weight
                motionSum += motion
                occlusionSum += occlusion
                area += 1
            }
        }

        let normalizedMotion = normalizedEnergy(sum: motionSum, area: area, divisor: 18)
        let normalizedOcclusion = normalizedEnergy(sum: occlusionSum, area: area, divisor: 24)
        let contactLikelihood = min(1, (0.55 * normalizedOcclusion) + (0.45 * normalizedMotion))

        let centroid: CGPoint?
        if weightSum > CGFloat(area) * 1.6 {
            centroid = CGPoint(
                x: weightedX / weightSum / CGFloat(currentFrame.width),
                y: weightedY / weightSum / CGFloat(currentFrame.height)
            )
        } else {
            centroid = nil
        }

        return FingerAccuracyKeyContactObservation(
            keyToken: region.keyToken,
            contactLikelihood: contactLikelihood,
            motionEnergy: normalizedMotion,
            occlusionEnergy: normalizedOcclusion,
            contactCentroid: centroid
        )
    }

    private func normalizedEnergy(sum: Float, area: Int, divisor: CGFloat) -> CGFloat {
        guard area > 0 else { return 0 }
        let average = CGFloat(sum) / CGFloat(area)
        return min(1, max(0, average / max(divisor, 0.001)))
    }

    private func pixelRect(for region: FingerAccuracyKeyRegion, in frame: LumaFrame) -> CGRect {
        let minX = (region.displayCenter.x - (region.normalizedSize.width / 2)) * CGFloat(frame.width)
        let minY = (region.displayCenter.y - (region.normalizedSize.height / 2)) * CGFloat(frame.height)
        return CGRect(
            x: minX,
            y: minY,
            width: region.normalizedSize.width * CGFloat(frame.width),
            height: region.normalizedSize.height * CGFloat(frame.height)
        )
    }

    private func makeLumaFrame(from cgImage: CGImage) -> LumaFrame? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerRow = sampleWidth
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight)

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
        return LumaFrame(width: sampleWidth, height: sampleHeight, pixels: pixels)
    }

    private static func keyRegions(for calibration: KeyboardCalibration) -> [FingerAccuracyKeyRegion] {
        let displayCorners = CalibrationCorner.allCases.map { displayPoint(from: calibration.corner($0)) }
        let minX = displayCorners.map(\.x).min() ?? 0
        let maxX = displayCorners.map(\.x).max() ?? 1
        let minY = displayCorners.map(\.y).min() ?? 0
        let maxY = displayCorners.map(\.y).max() ?? 1
        let keyboardBounds = CGRect(x: minX, y: minY, width: max(maxX - minX, 0.1), height: max(maxY - minY, 0.1))
        let keyWidth = keyboardBounds.width / 13.2
        let keyHeight = keyboardBounds.height / 4.1

        var regions = KeyboardLayout.keys.compactMap { key -> FingerAccuracyKeyRegion? in
            guard let center = calibration.keyCenter(for: key.character) else { return nil }
            return FingerAccuracyKeyRegion(
                keyToken: String(key.character).lowercased(),
                displayCenter: displayPoint(from: center),
                normalizedSize: CGSize(width: keyWidth * 0.84, height: keyHeight * 0.8)
            )
        }

        regions.append(
            FingerAccuracyKeyRegion(
                keyToken: "space",
                displayCenter: displayPoint(from: FingerAccuracyViewModel.spacebarCenter(for: calibration)),
                normalizedSize: CGSize(width: keyWidth * 4.8, height: keyHeight * 0.9)
            )
        )

        return regions
    }

    private static func displayPoint(from visionPoint: CGPoint) -> CGPoint {
        CGPoint(x: 1 - visionPoint.x, y: 1 - visionPoint.y)
    }
}
