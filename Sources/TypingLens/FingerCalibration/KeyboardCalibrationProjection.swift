import CoreGraphics

enum KeyboardCalibrationProjection {
    static func project(
        key: KeyboardKeyDefinition,
        calibration: FingerCalibration,
        canvasSize: CGSize
    ) -> CGPoint {
        let baseX = key.normalizedCenterX * canvasSize.width
        let baseY = key.normalizedCenterY * canvasSize.height

        let scaled = CGPoint(
            x: baseX * calibration.transform.scaleX,
            y: baseY * calibration.transform.scaleY
        )

        let adjusted = CGPoint(
            x: scaled.x + (calibration.keyAdjustments[key.id]?.offsetX ?? 0),
            y: scaled.y + (calibration.keyAdjustments[key.id]?.offsetY ?? 0)
        )

        let rotation = calibration.transform.rotationRadians
        if rotation == 0 {
            return CGPoint(
                x: adjusted.x + calibration.transform.offsetX,
                y: adjusted.y + calibration.transform.offsetY
            )
        }

        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let dx = adjusted.x - canvasCenter.x
        let dy = adjusted.y - canvasCenter.y
        let cosine = cos(rotation)
        let sine = sin(rotation)

        let rotatedX = (dx * cosine) - (dy * sine) + canvasCenter.x
        let rotatedY = (dx * sine) + (dy * cosine) + canvasCenter.y

        return CGPoint(
            x: rotatedX + calibration.transform.offsetX,
            y: rotatedY + calibration.transform.offsetY
        )
    }

    static func projectedRect(
        key: KeyboardKeyDefinition,
        calibration: FingerCalibration,
        canvasSize: CGSize
    ) -> CGRect {
        let center = project(key: key, calibration: calibration, canvasSize: canvasSize)
        let scaledWidth = abs(key.normalizedWidth * canvasSize.width * calibration.transform.scaleX)
        let scaledHeight = abs(key.normalizedHeight * canvasSize.height * calibration.transform.scaleY)

        if scaledWidth <= 0 || scaledHeight <= 0 {
            return CGRect(origin: .zero, size: .zero)
        }

        return CGRect(
            x: center.x - (scaledWidth / 2),
            y: center.y - (scaledHeight / 2),
            width: scaledWidth,
            height: scaledHeight
        )
    }
}
