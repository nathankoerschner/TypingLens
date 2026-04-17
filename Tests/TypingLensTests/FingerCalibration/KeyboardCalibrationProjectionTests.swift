import Foundation
import XCTest
@testable import TypingLens

final class KeyboardCalibrationProjectionTests: XCTestCase {
    func testProjectionAppliesGlobalTransformAndLocalAdjustment() {
        let calibration = FingerCalibration.makeDefault(name: "Test", imageSize: CGSize(width: 1_000, height: 500))
        var adjusted = calibration
        adjusted.transform.scaleX = 1.15
        adjusted.transform.scaleY = 1.1
        adjusted.transform.offsetX = 10
        adjusted.transform.offsetY = 20
        adjusted.keyAdjustments["Q"] = KeyAdjustment(offsetX: 3, offsetY: 4)

        let key = KeyboardKeyDefinition(
            id: "Q",
            label: "Q",
            normalizedCenterX: 0.20,
            normalizedCenterY: 0.30,
            normalizedWidth: 0.05,
            normalizedHeight: 0.08
        )

        let projected = KeyboardCalibrationProjection.project(
            key: key,
            calibration: adjusted,
            canvasSize: CGSize(width: 1_000, height: 500)
        )

        let expectedBaseX = 0.20 * 1_000
        let expectedBaseY = 0.30 * 500

        XCTAssertEqual(projected.x, expectedBaseX * 1.15 + 3 + 10, accuracy: 0.001)
        XCTAssertEqual(projected.y, expectedBaseY * 1.1 + 4 + 20, accuracy: 0.001)
    }

    func testProjectionBuildsRectFromProjectedCenterAndKeySize() {
        var calibration = FingerCalibration.makeDefault(name: "Test", imageSize: CGSize(width: 1_000, height: 500))
        calibration.transform.scaleX = 0.8
        calibration.transform.scaleY = 1.2

        let key = KeyboardKeyDefinition(
            id: "A",
            label: "A",
            normalizedCenterX: 0.10,
            normalizedCenterY: 0.20,
            normalizedWidth: 0.10,
            normalizedHeight: 0.10
        )

        let rect = KeyboardCalibrationProjection.projectedRect(
            key: key,
            calibration: calibration,
            canvasSize: CGSize(width: 1_000, height: 500)
        )

        XCTAssertEqual(rect.width, 0.10 * 1_000 * 0.8, accuracy: 0.001)
        XCTAssertEqual(rect.height, 0.10 * 500 * 1.2, accuracy: 0.001)

        XCTAssertEqual(rect.midX, 100 * 0.8, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 100 * 1.2, accuracy: 0.001)
    }
}
