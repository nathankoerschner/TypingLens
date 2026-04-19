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
    static func attribute(
        keyCenter: CGPoint,
        fingertips: [FingertipSample]
    ) -> (finger: Finger, distance: Double)? {
        guard !fingertips.isEmpty else { return nil }
        var best: (finger: Finger, distance: Double)?
        for tip in fingertips {
            let dx = tip.position.x - keyCenter.x
            let dy = tip.position.y - keyCenter.y
            let d = Double(sqrt(dx * dx + dy * dy))
            if best == nil || d < best!.distance {
                best = (tip.finger, d)
            }
        }
        return best
    }
}
