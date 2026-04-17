import Foundation

@MainActor
final class FingerCalibrationViewModel: ObservableObject {
    @Published var cameraStatus = "Camera not started"
    @Published var calibrationStatus = "No active calibration"
    @Published var trackingStatus = "Tracking unavailable"
    @Published var selectedKeyLabel: String?
    @Published var recentEventSummary: [String] = []
}
