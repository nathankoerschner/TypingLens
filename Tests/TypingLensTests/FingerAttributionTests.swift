import XCTest
@testable import TypingLens

final class FingerAttributionTests: XCTestCase {
    private let keyCenter = CGPoint(x: 0.5, y: 0.5)

    func testNearestFingerWinsWhenNoExpectedFingerProvided() {
        let tips: [FingertipSample] = [
            FingertipSample(finger: .leftIndex, position: CGPoint(x: 0.50, y: 0.52), confidence: 0.9),
            FingertipSample(finger: .leftMiddle, position: CGPoint(x: 0.50, y: 0.55), confidence: 0.9)
        ]
        let result = FingerAttributor.attribute(keyCenter: keyCenter, fingertips: tips)
        XCTAssertEqual(result?.finger, .leftIndex)
    }

    func testExpectedFingerBiasBreaksNearTie() {
        // Competitor is ~8% closer to the key (within the ~11% bias headroom).
        // The tiny bias should flip attribution to the expected finger.
        let tips: [FingertipSample] = [
            FingertipSample(finger: .leftIndex, position: CGPoint(x: 0.50, y: 0.525), confidence: 0.9),
            FingertipSample(finger: .leftMiddle, position: CGPoint(x: 0.50, y: 0.523), confidence: 0.9)
        ]
        let result = FingerAttributor.attribute(
            keyCenter: keyCenter,
            fingertips: tips,
            expectedFinger: .leftIndex
        )
        XCTAssertEqual(result?.finger, .leftIndex)
    }

    func testCompetitorOutsideBiasWindowStillWins() {
        // Expected finger is 2× farther than competitor — well outside the
        // ~54% bias headroom at scale 0.65. Competitor wins, so clear
        // wrong-finger use is still surfaced.
        let tips: [FingertipSample] = [
            FingertipSample(finger: .leftIndex, position: CGPoint(x: 0.50, y: 0.540), confidence: 0.9),
            FingertipSample(finger: .leftMiddle, position: CGPoint(x: 0.50, y: 0.520), confidence: 0.9)
        ]
        let result = FingerAttributor.attribute(
            keyCenter: keyCenter,
            fingertips: tips,
            expectedFinger: .leftIndex
        )
        XCTAssertEqual(result?.finger, .leftMiddle)
    }

    func testExpectedFingerBiasDoesNotHideClearErrors() {
        // The middle finger is clearly closer (well beyond the 11% bias headroom).
        // Attribution should still report middle, preserving visibility of real mistakes.
        let tips: [FingertipSample] = [
            FingertipSample(finger: .leftIndex, position: CGPoint(x: 0.50, y: 0.60), confidence: 0.9),
            FingertipSample(finger: .leftMiddle, position: CGPoint(x: 0.50, y: 0.51), confidence: 0.9)
        ]
        let result = FingerAttributor.attribute(
            keyCenter: keyCenter,
            fingertips: tips,
            expectedFinger: .leftIndex
        )
        XCTAssertEqual(result?.finger, .leftMiddle)
    }

    func testAttributionReturnsTrueDistanceNotBiasedValue() {
        let tips: [FingertipSample] = [
            FingertipSample(finger: .leftIndex, position: CGPoint(x: 0.5, y: 0.6), confidence: 0.9)
        ]
        let result = FingerAttributor.attribute(
            keyCenter: keyCenter,
            fingertips: tips,
            expectedFinger: .leftIndex
        )
        XCTAssertEqual(result?.distance ?? 0, 0.1, accuracy: 1e-9)
    }

    func testLowConfidenceTipsAreIgnored() {
        let tips: [FingertipSample] = [
            FingertipSample(finger: .leftIndex, position: CGPoint(x: 0.5, y: 0.5), confidence: 0.1),
            FingertipSample(finger: .leftMiddle, position: CGPoint(x: 0.5, y: 0.6), confidence: 0.9)
        ]
        let result = FingerAttributor.attribute(keyCenter: keyCenter, fingertips: tips)
        XCTAssertEqual(result?.finger, .leftMiddle)
    }

    func testAttributionReturnsNilWhenNoTipMeetsConfidenceFloor() {
        let tips: [FingertipSample] = [
            FingertipSample(finger: .leftIndex, position: CGPoint(x: 0.5, y: 0.5), confidence: 0.1)
        ]
        let result = FingerAttributor.attribute(keyCenter: keyCenter, fingertips: tips)
        XCTAssertNil(result)
    }
}
