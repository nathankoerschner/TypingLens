import CoreGraphics
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
            handStrokes: []
        )
        let samples = FingerAccuracyViewModel.extractFingertips(from: overlay, swapHands: false)
        XCTAssertEqual(samples.count, 10)
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

    func testHandleKeyDownAdvancesPromptWhenKeyAndFingerMatch() throws {
        let calibration = KeyboardCalibration.defaultNormalized
        let keyCenter = try XCTUnwrap(calibration.keyCenter(for: "a"))
        let viewModel = FingerAccuracyViewModel(
            cameraController: MockVisionTrackingCameraController(),
            promptText: "ab",
            initialFingertips: [FingertipSample(finger: .leftPinky, position: keyCenter, confidence: 1)]
        )

        viewModel.finishCalibration()
        viewModel.handleKeyDown("a")

        XCTAssertEqual(viewModel.currentPromptIndex, 1)
        XCTAssertEqual(viewModel.promptFeedback, "Right key, right finger")
        XCTAssertTrue(viewModel.promptFeedbackIsSuccess)
        XCTAssertEqual(viewModel.results.first?.character, "a")
        XCTAssertTrue(viewModel.results.first?.isCorrect ?? false)
    }

    func testHandleKeyDownDoesNotAdvancePromptWhenFingerIsWrong() throws {
        let calibration = KeyboardCalibration.defaultNormalized
        let keyCenter = try XCTUnwrap(calibration.keyCenter(for: "a"))
        let viewModel = FingerAccuracyViewModel(
            cameraController: MockVisionTrackingCameraController(),
            promptText: "ab",
            initialFingertips: [FingertipSample(finger: .rightIndex, position: keyCenter, confidence: 1)]
        )

        viewModel.finishCalibration()
        viewModel.handleKeyDown("a")

        XCTAssertEqual(viewModel.currentPromptIndex, 0)
        XCTAssertEqual(viewModel.promptFeedback, "Right key, wrong finger")
        XCTAssertFalse(viewModel.promptFeedbackIsSuccess)
        XCTAssertEqual(viewModel.results.first?.character, "a")
        XCTAssertFalse(viewModel.results.first?.isCorrect ?? true)
    }

    func testHandleKeyDownShowsWrongKeyWhenPromptCharacterDoesNotMatch() throws {
        let calibration = KeyboardCalibration.defaultNormalized
        let keyCenter = try XCTUnwrap(calibration.keyCenter(for: "s"))
        let viewModel = FingerAccuracyViewModel(
            cameraController: MockVisionTrackingCameraController(),
            promptText: "ab",
            initialFingertips: [FingertipSample(finger: .leftRing, position: keyCenter, confidence: 1)]
        )

        viewModel.finishCalibration()
        viewModel.handleKeyDown("s")

        XCTAssertEqual(viewModel.currentPromptIndex, 0)
        XCTAssertEqual(viewModel.promptFeedback, "Wrong key")
        XCTAssertFalse(viewModel.promptFeedbackIsSuccess)
        XCTAssertEqual(viewModel.results.first?.character, "s")
        XCTAssertTrue(viewModel.results.first?.isCorrect ?? false)
    }

    func testHandleKeyDownAcceptsSpaceFromAnyFinger() {
        let calibration = KeyboardCalibration.defaultNormalized
        let spacebarCenter = FingerAccuracyViewModel.spacebarCenter(for: calibration)
        let viewModel = FingerAccuracyViewModel(
            cameraController: MockVisionTrackingCameraController(),
            promptText: " a",
            initialFingertips: [FingertipSample(finger: .leftPinky, position: spacebarCenter, confidence: 1)]
        )

        viewModel.finishCalibration()
        viewModel.handleKeyDown(" ")

        XCTAssertEqual(viewModel.currentPromptIndex, 1)
        XCTAssertEqual(viewModel.promptFeedback, "Right key")
        XCTAssertTrue(viewModel.promptFeedbackIsSuccess)
        XCTAssertEqual(viewModel.results.first?.expectedFingerDisplayName, "Any finger")
        XCTAssertTrue(viewModel.results.first?.isCorrect ?? false)
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
            handStrokes: []
        )
    }
}

private final class MockVisionTrackingCameraController: VisionTrackingCameraControlling {
    var onFrameUpdate: ((VisionTrackingCameraFrame, VisionTrackingOverlayState) -> Void)?
    var onStatusUpdate: ((String, Bool) -> Void)?

    func start() {}
    func stop() {}
    func requestCameraAccess() {}
}
