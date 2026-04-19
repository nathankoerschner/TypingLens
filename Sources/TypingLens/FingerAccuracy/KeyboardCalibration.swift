import CoreGraphics
import Foundation

enum CalibrationCorner: Int, CaseIterable {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

    var label: String {
        switch self {
        case .topLeft: return "Top-left"
        case .topRight: return "Top-right"
        case .bottomRight: return "Bottom-right"
        case .bottomLeft: return "Bottom-left"
        }
    }

    var shortLabel: String {
        switch self {
        case .topLeft: return "TL"
        case .topRight: return "TR"
        case .bottomRight: return "BR"
        case .bottomLeft: return "BL"
        }
    }
}

struct KeyboardCalibration: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let defaultNormalized = KeyboardCalibration(
        topLeft: CGPoint(x: 0.15, y: 0.65),
        topRight: CGPoint(x: 0.85, y: 0.65),
        bottomRight: CGPoint(x: 0.85, y: 0.25),
        bottomLeft: CGPoint(x: 0.15, y: 0.25)
    )

    func corner(_ corner: CalibrationCorner) -> CGPoint {
        switch corner {
        case .topLeft: return topLeft
        case .topRight: return topRight
        case .bottomRight: return bottomRight
        case .bottomLeft: return bottomLeft
        }
    }

    mutating func setCorner(_ corner: CalibrationCorner, to point: CGPoint) {
        switch corner {
        case .topLeft: topLeft = point
        case .topRight: topRight = point
        case .bottomRight: bottomRight = point
        case .bottomLeft: bottomLeft = point
        }
    }

    func keyCenter(for character: Character) -> CGPoint? {
        guard let key = KeyboardLayout.key(for: character) else { return nil }
        let u = key.col / KeyboardLayout.maxCol
        let v = Double(key.row) / Double(KeyboardLayout.rowCount - 1)
        return project(u: u, v: v)
    }

    func project(u: Double, v: Double) -> CGPoint {
        let mu = 1 - u
        let mv = 1 - v
        let x = mu * mv * topLeft.x + u * mv * topRight.x + u * v * bottomRight.x + mu * v * bottomLeft.x
        let y = mu * mv * topLeft.y + u * mv * topRight.y + u * v * bottomRight.y + mu * v * bottomLeft.y
        return CGPoint(x: x, y: y)
    }
}
