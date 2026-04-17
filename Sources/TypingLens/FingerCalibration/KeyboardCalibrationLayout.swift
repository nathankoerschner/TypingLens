import Foundation

enum KeyboardCalibrationLayout {
    static let supportedKeys: [KeyboardKeyDefinition] = {
        func row(
            _ labels: [String],
            y: Double,
            startX: Double,
            step: Double,
            width: Double = 0.056,
            height: Double = 0.082
        ) -> [KeyboardKeyDefinition] {
            labels.enumerated().map { index, label in
                KeyboardKeyDefinition(
                    id: label,
                    label: label,
                    normalizedCenterX: startX + (step * Double(index)),
                    normalizedCenterY: y,
                    normalizedWidth: width,
                    normalizedHeight: height
                )
            }
        }

        let row1 = row(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], y: 0.28, startX: 0.13, step: 0.074)
        let row2 = row(["A", "S", "D", "F", "G", "H", "J", "K", "L"], y: 0.45, startX: 0.17, step: 0.074)
        let row3 = row(["Z", "X", "C", "V", "B", "N", "M"], y: 0.62, startX: 0.245, step: 0.074)
        let space = KeyboardKeyDefinition(
            id: "SPACE",
            label: "Space",
            normalizedCenterX: 0.50,
            normalizedCenterY: 0.77,
            normalizedWidth: 0.34,
            normalizedHeight: 0.075
        )

        return row1 + row2 + row3 + [space]
    }()

    static let supportedKeyIDs: Set<String> = Set(supportedKeys.map(\.id))

    static func definition(for keyID: String) -> KeyboardKeyDefinition? {
        supportedKeys.first(where: { $0.id == keyID })
    }
}
