import CoreGraphics
import Foundation

struct FingertipSample: Equatable {
    let finger: Finger
    let position: CGPoint
    let confidence: Double
}

struct AttributionResult: Identifiable, Equatable {
    let id = UUID()
    let character: Character
    let expectedFinger: Finger
    let acceptedFingers: Set<Finger>
    let detectedFinger: Finger?
    let distance: Double?
    let keyCenter: CGPoint?
    let timestamp: Date

    var isUncertain: Bool { detectedFinger == nil }

    var isCorrect: Bool {
        guard let detectedFinger else { return false }
        return acceptedFingers.contains(detectedFinger)
    }

    var expectedFingerDisplayName: String {
        if acceptedFingers == Set(Finger.allCases) {
            return "Any finger"
        }
        if acceptedFingers == Set([.leftThumb, .rightThumb]) {
            return "Thumbs"
        }
        return expectedFinger.displayName
    }
}

enum FingerAttributor {
    static let minAttributionConfidence: Double = 0.3

    // Distance multiplier applied to the expected finger only. At 0.60 the
    // expected finger wins when its true distance is within 1/0.60 ≈ 1.67× of
    // the nearest competitor — generous enough to absorb Vision jitter and
    // adjacency confusion for most home-row typing, while systematically-wrong
    // finger use still drives accuracy visibly down over a session.
    static let expectedFingerDistanceScale: Double = 0.60

    static func attribute(
        keyCenter: CGPoint,
        fingertips: [FingertipSample],
        expectedFinger: Finger? = nil
    ) -> (finger: Finger, distance: Double)? {
        let confident = fingertips.filter { $0.confidence >= minAttributionConfidence }
        guard !confident.isEmpty else { return nil }
        var best: (finger: Finger, trueDistance: Double, scoredDistance: Double)?
        for tip in confident {
            let dx = tip.position.x - keyCenter.x
            let dy = tip.position.y - keyCenter.y
            let trueDistance = Double(sqrt(dx * dx + dy * dy))
            let scoredDistance = tip.finger == expectedFinger
                ? trueDistance * expectedFingerDistanceScale
                : trueDistance
            if best == nil || scoredDistance < best!.scoredDistance {
                best = (tip.finger, trueDistance, scoredDistance)
            }
        }
        return best.map { ($0.finger, $0.trueDistance) }
    }
}
