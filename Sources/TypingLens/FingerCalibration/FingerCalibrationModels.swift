import Foundation
import CoreGraphics

struct CGSizeCodable: Codable, Equatable {
    var width: Double
    var height: Double

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    init(_ size: CGSize) {
        width = size.width
        height = size.height
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

struct FingerCalibration: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var imageSize: CGSizeCodable
    var transform: KeyboardTransform
    var keyAdjustments: [String: KeyAdjustment]

    static func makeDefault(
        name: String,
        imageSize: CGSize = CGSize(width: 1_000, height: 500),
        id: UUID = UUID()
    ) -> FingerCalibration {
        FingerCalibration(
            id: id,
            name: name,
            createdAt: Date(),
            updatedAt: Date(),
            imageSize: CGSizeCodable(imageSize),
            transform: .identity,
            keyAdjustments: [:]
        )
    }
}

struct KeyboardTransform: Codable, Equatable {
    var offsetX: Double
    var offsetY: Double
    var scaleX: Double
    var scaleY: Double
    var rotationRadians: Double

    static let identity = KeyboardTransform(
        offsetX: 0,
        offsetY: 0,
        scaleX: 1,
        scaleY: 1,
        rotationRadians: 0
    )
}

struct KeyAdjustment: Codable, Equatable {
    var offsetX: Double
    var offsetY: Double

    static let zero = KeyAdjustment(offsetX: 0, offsetY: 0)
}

struct KeyboardKeyDefinition: Equatable, Identifiable {
    let id: String
    let label: String
    let normalizedCenterX: Double
    let normalizedCenterY: Double
    let normalizedWidth: Double
    let normalizedHeight: Double
}

struct SavedCalibrationSummary: Equatable, Identifiable {
    let id: UUID
    let name: String
    let updatedAt: Date
    let fileURL: URL
}
