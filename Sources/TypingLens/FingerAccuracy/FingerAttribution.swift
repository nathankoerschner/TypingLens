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
        expectedFinger: Finger? = nil,
        contactCentroid: CGPoint? = nil,
        contactWeight: CGFloat = 0
    ) -> (finger: Finger, distance: Double)? {
        let confident = fingertips.filter { $0.confidence >= minAttributionConfidence }
        guard !confident.isEmpty else { return nil }

        var best: (finger: Finger, trueDistance: Double, scoredDistance: Double)?
        for tip in confident {
            let trueDistance = distance(from: tip.position, to: keyCenter)
            let blended = blendedDistance(
                from: tip.position,
                keyCenter: keyCenter,
                contactCentroid: contactCentroid,
                contactWeight: contactWeight
            )
            let scoredDistance = tip.finger == expectedFinger
                ? blended * expectedFingerDistanceScale
                : blended

            if best == nil || scoredDistance < best!.scoredDistance {
                best = (tip.finger, trueDistance, scoredDistance)
            }
        }
        return best.map { ($0.finger, $0.trueDistance) }
    }

    private static func blendedDistance(
        from fingertip: CGPoint,
        keyCenter: CGPoint,
        contactCentroid: CGPoint?,
        contactWeight: CGFloat
    ) -> Double {
        let keyDistance = distance(from: fingertip, to: keyCenter)
        guard let contactCentroid, contactWeight > 0.01 else { return keyDistance }

        let contactDistance = distance(from: fingertip, to: contactCentroid)
        let clampedWeight = min(max(contactWeight, 0), 0.9)
        return ((1 - Double(clampedWeight)) * keyDistance) + (Double(clampedWeight) * contactDistance)
    }

    private static func distance(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return Double(sqrt(dx * dx + dy * dy))
    }
}
