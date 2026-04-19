import XCTest
import Vision
@testable import TypingLens

final class FingerAccuracyFingertipExtractionTests: XCTestCase {
    func testKeyboardLayoutDoesNotMapSpacebar() {
        XCTAssertNil(KeyboardLayout.key(for: " "))
    }

    func testDefaultCalibrationUsesMirroredVisionCoordinates() {
        let calibration = KeyboardCalibration.defaultNormalized

        XCTAssertGreaterThan(calibration.topLeft.x, calibration.topRight.x)
        XCTAssertGreaterThan(calibration.bottomLeft.x, calibration.bottomRight.x)
    }

    func testDefaultCalibrationDrawsLeftKeysToTheVisualLeft() throws {
        let calibration = KeyboardCalibration.defaultNormalized

        let qDisplayX = try XCTUnwrap(Self.displayX(for: "q", calibration: calibration))
        let pDisplayX = try XCTUnwrap(Self.displayX(for: "p", calibration: calibration))
        let aDisplayX = try XCTUnwrap(Self.displayX(for: "a", calibration: calibration))
        let semicolonDisplayX = try XCTUnwrap(Self.displayX(for: ";", calibration: calibration))
        let zDisplayX = try XCTUnwrap(Self.displayX(for: "z", calibration: calibration))
        let slashDisplayX = try XCTUnwrap(Self.displayX(for: "/", calibration: calibration))

        XCTAssertLessThan(qDisplayX, pDisplayX)
        XCTAssertLessThan(aDisplayX, semicolonDisplayX)
        XCTAssertLessThan(zDisplayX, slashDisplayX)
    }

    func testExtractFingertipsFindsAllFiveTipsOnOneHand() {
        let overlay = Self.makeHandOverlay(prefix: "hand-0", wristX: 0.3)
        let samples = FingerAccuracyViewModel.extractFingertips(from: overlay, swapHands: false)
        XCTAssertEqual(samples.count, 5)
        let fingers = Set(samples.map { $0.finger })
        XCTAssertEqual(fingers, [.rightThumb, .rightIndex, .rightMiddle, .rightRing, .rightPinky])
    }

    func testExtractFingertipsAssignsSingleDisplayLeftHandToLeftFingers() {
        let overlay = Self.makeHandOverlay(prefix: "hand-0", wristX: 0.7)
        let samples = FingerAccuracyViewModel.extractFingertips(from: overlay, swapHands: false)

        let fingers = Set(samples.map { $0.finger })
        XCTAssertEqual(fingers, [.leftThumb, .leftIndex, .leftMiddle, .leftRing, .leftPinky])
    }

    func testSwapHandsInvertsSingleHandSideInference() {
        let overlay = Self.makeHandOverlay(prefix: "hand-0", wristX: 0.7)
        let samples = FingerAccuracyViewModel.extractFingertips(from: overlay, swapHands: true)

        let fingers = Set(samples.map { $0.finger })
        XCTAssertEqual(fingers, [.rightThumb, .rightIndex, .rightMiddle, .rightRing, .rightPinky])
    }

    func testExtractFingertipsAssignsLeftAndRightByTipPosition() {
        var landmarks: [VisionTrackingLandmark] = []
        landmarks.append(contentsOf: Self.makeHandOverlay(prefix: "hand-0", wristX: 0.2).handPoints)
        landmarks.append(contentsOf: Self.makeHandOverlay(prefix: "hand-1", wristX: 0.7).handPoints)
        let overlay = VisionTrackingOverlayState(
            posePoints: [],
            poseStrokes: [],
            handPoints: landmarks,
            handStrokes: [],
            handInfos: []
        )
        let samples = FingerAccuracyViewModel.extractFingertips(from: overlay, swapHands: false)
        XCTAssertEqual(samples.count, 10)
        let fingers = Set(samples.map { $0.finger })
        XCTAssertTrue(fingers.contains(.leftIndex))
        XCTAssertTrue(fingers.contains(.rightIndex))
    }

    func testChiralityOverridesCentroidHeuristic() {
        // Single hand on the visually-right side of the screen (low Vision X).
        // The centroid heuristic would call this a right hand, but chirality says left.
        var overlay = Self.makeHandOverlay(prefix: "hand-0", wristX: 0.2)
        overlay.handInfos = [VisionTrackingHandInfo(prefix: "hand-0", handedness: .left)]
        let samples = FingerAccuracyViewModel.extractFingertips(from: overlay, swapHands: false)
        let fingers = Set(samples.map { $0.finger })
        XCTAssertEqual(fingers, [.leftThumb, .leftIndex, .leftMiddle, .leftRing, .leftPinky])
    }

    func testTwoHandSameChiralityFallsBackToCentroidSort() {
        // Vision sometimes reports both hands with the same chirality on a mirrored
        // front-camera feed. In that case we should ignore chirality and fall back
        // to the centroid-ordered position assignment.
        var landmarks: [VisionTrackingLandmark] = []
        landmarks.append(contentsOf: Self.makeHandOverlay(prefix: "hand-0", wristX: 0.2).handPoints)
        landmarks.append(contentsOf: Self.makeHandOverlay(prefix: "hand-1", wristX: 0.7).handPoints)
        let overlay = VisionTrackingOverlayState(
            posePoints: [],
            poseStrokes: [],
            handPoints: landmarks,
            handStrokes: [],
            handInfos: [
                VisionTrackingHandInfo(prefix: "hand-0", handedness: .right),
                VisionTrackingHandInfo(prefix: "hand-1", handedness: .right)
            ]
        )
        let samples = FingerAccuracyViewModel.extractFingertips(from: overlay, swapHands: false)
        let fingers = Set(samples.map { $0.finger })
        XCTAssertTrue(fingers.contains(.leftIndex))
        XCTAssertTrue(fingers.contains(.rightIndex))
    }

    func testExtractFingertipsDoesNotRequireWristPoint() {
        let overlay = Self.makeHandOverlay(prefix: "hand-0", wristX: 0.3, includeWrist: false)
        let samples = FingerAccuracyViewModel.extractFingertips(from: overlay, swapHands: false)

        XCTAssertEqual(samples.count, 5)
        XCTAssertTrue(samples.contains { $0.finger == .rightIndex })
    }

    private static func displayX(
        for character: Character,
        calibration: KeyboardCalibration
    ) -> CGFloat? {
        calibration.keyCenter(for: character).map { 1 - $0.x }
    }

    private static func makeHandOverlay(
        prefix: String,
        wristX: Double,
        includeWrist: Bool = true
    ) -> VisionTrackingOverlayState {
        var joints: [(VNHumanHandPoseObservation.JointName, CGFloat)] = [
            (.thumbTip, CGFloat(wristX + 0.05)),
            (.indexTip, CGFloat(wristX + 0.06)),
            (.middleTip, CGFloat(wristX + 0.07)),
            (.ringTip, CGFloat(wristX + 0.08)),
            (.littleTip, CGFloat(wristX + 0.09))
        ]
        if includeWrist {
            joints.insert((.wrist, CGFloat(wristX)), at: 0)
        }

        let landmarks = joints.map { joint, x in
            VisionTrackingLandmark(
                id: "\(prefix)-\(joint.rawValue.rawValue)",
                x: x,
                y: 0.5,
                confidence: 0.9
            )
        }
        return VisionTrackingOverlayState(
            posePoints: [],
            poseStrokes: [],
            handPoints: landmarks,
            handStrokes: [],
            handInfos: []
        )
    }
}
