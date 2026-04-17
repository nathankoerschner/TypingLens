import Foundation
import CoreGraphics

@MainActor
final class FingerCalibrationViewModel: ObservableObject {
    @Published var cameraStatus = "Camera not started"
    @Published var calibrationStatus = "No active calibration"
    @Published var trackingStatus = "Tracking unavailable"
    @Published var selectedKeyLabel: String?
    @Published var recentEventSummary: [String] = []

    @Published var isFrozen = false
    @Published var activeCalibration: FingerCalibration?
    @Published var savedCalibrations: [SavedCalibrationSummary] = []
    @Published var selectedKeyID: String?
    @Published var draftCalibrationName: String = ""

    @Published var availableCameras: [CameraOption] = []
    @Published var selectedCameraID: String?
    @Published var isCameraRunning = false
    @Published var isCameraMirrored = false {
        didSet {
            cameraService.isMirroringEnabled = isCameraMirrored
        }
    }
    @Published var liveFrame: CGImage?
    @Published var frozenFrame: CGImage?
    @Published var recentTrackedFrames: [TrackedFrame] = []
    @Published var showKeyboardOverlay = true
    @Published var showKeyCenters = true
    @Published var showFingerLabels = true
    @Published var showHandLandmarks = true
    @Published var showDebugAnnotations = false

    @Published private(set) var canvasSize: CGSize = CGSize(width: 1_000, height: 620)

    private let store: FingerCalibrationStore
    private let appState: AppState
    private let cameraService: CameraFrameServing
    private let handTrackingService: HandTrackingServing
    private var frozenTrackedFrame: TrackedFrame?
    private let maxFrameHistory = 90

    init(
        appState: AppState,
        store: FingerCalibrationStore = FingerCalibrationStore(fileLocations: FileLocations()),
        cameraService: CameraFrameServing = AVFoundationCameraFrameService(),
        handTrackingService: HandTrackingServing = UnavailableHandTrackingService(),
        defaultCalibration: FingerCalibration = FingerCalibration.makeDefault(name: "Untitled Calibration")
    ) {
        self.appState = appState
        self.store = store
        self.cameraService = cameraService
        self.handTrackingService = handTrackingService
        self.activeCalibration = defaultCalibration
        self.cameraService.isMirroringEnabled = false
        self.draftCalibrationName = defaultCalibration.name
        self.selectedKeyLabel = nil

        refreshSavedCalibrations()
        refreshAvailableCameras()
        trackingStatus = handTrackingService.isAvailable ? "\(handTrackingService.backendName) ready" : "\(handTrackingService.backendName) unavailable"
    }

    deinit {
        cameraService.stop()
    }

    var displayedFrame: CGImage? {
        isFrozen ? frozenFrame : liveFrame
    }

    var displayedFingertips: [TrackedFingertip] {
        let frame = isFrozen ? frozenTrackedFrame : recentTrackedFrames.last
        return frame?.fingertips ?? []
    }

    var canvasStatusMessage: String? {
        if availableCameras.isEmpty {
            return "No camera available"
        }

        if isCameraRunning {
            if displayedFrame == nil {
                return "Camera started\nWaiting for frame"
            }

            if recentTrackedFrames.isEmpty {
                return trackingStatus
            }

            return nil
        }

        return nil
    }

    var projectedKeys: [String: CGRect] {
        guard let activeCalibration else { return [:] }
        return Dictionary(uniqueKeysWithValues: KeyboardCalibrationLayout.supportedKeys.map { key in
            (key.id, KeyboardCalibrationProjection.projectedRect(key: key, calibration: activeCalibration, canvasSize: canvasSize))
        })
    }

    var projectedKeyCenters: [String: CGPoint] {
        guard let activeCalibration else { return [:] }
        return Dictionary(uniqueKeysWithValues: KeyboardCalibrationLayout.supportedKeys.map { key in
            (key.id, KeyboardCalibrationProjection.project(key: key, calibration: activeCalibration, canvasSize: canvasSize))
        })
    }

    func updateCanvasSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if canvasSize == size { return }
        canvasSize = size
    }

    func refreshAvailableCameras() {
        availableCameras = cameraService.availableCameras()

        if let selectedCameraID, availableCameras.contains(where: { $0.id == selectedCameraID }) {
            return
        }

        selectedCameraID = availableCameras.first?.id
        if availableCameras.isEmpty {
            cameraStatus = "No camera available"
            trackingStatus = "Tracking unavailable"
        }
    }

    func setCameraSelection(_ cameraID: String) {
        guard availableCameras.contains(where: { $0.id == cameraID }) else { return }
        selectedCameraID = cameraID
    }

    func setCameraMirroring(_ isEnabled: Bool) {
        isCameraMirrored = isEnabled
    }

    func startCamera() {
        guard !isCameraRunning else { return }

        guard let selectedCameraID else {
            cameraStatus = "Select a camera before starting"
            appState.fingerCalibrationStatus = cameraStatus
            return
        }

        cameraService.onFrame = { [weak self] frame in
            Task { @MainActor in
                self?.handleCapturedFrame(frame)
            }
        }

        do {
            try cameraService.start(cameraID: selectedCameraID)
            isCameraRunning = true
            cameraStatus = "Camera running"
            appState.fingerCalibrationStatus = cameraStatus
            trackingStatus = handTrackingService.isAvailable ? "\(handTrackingService.backendName) ready" : "\(handTrackingService.backendName) unavailable"
        } catch {
            isCameraRunning = false
            cameraStatus = "Failed to start camera: \(error.localizedDescription)"
            appState.fingerCalibrationStatus = cameraStatus
        }
    }

    func stopCamera() {
        guard isCameraRunning else { return }

        cameraService.stop()
        isCameraRunning = false
        liveFrame = nil
        cameraStatus = "Camera stopped"
        appState.fingerCalibrationStatus = cameraStatus
    }

    func freezeFrame() {
        isFrozen = true
        frozenFrame = liveFrame
        frozenTrackedFrame = recentTrackedFrames.last
        calibrationStatus = "Frame frozen for editing"
        appState.fingerCalibrationStatus = "Frame frozen for editing"
    }

    func resumeLiveFrame() {
        isFrozen = false
        frozenFrame = nil
        frozenTrackedFrame = nil
        calibrationStatus = "Live frame editing resumed"
        appState.fingerCalibrationStatus = "Live frame editing resumed"
    }

    func selectKey(_ keyID: String?) {
        selectedKeyID = keyID
        selectedKeyLabel = keyID.flatMap { KeyboardCalibrationLayout.definition(for: $0)?.label }
    }

    func moveKeyboard(by translation: CGSize) {
        guard var calibration = activeCalibration else { return }
        calibration.transform.offsetX += translation.width
        calibration.transform.offsetY += translation.height
        activeCalibration = calibration
        calibrationStatus = "Keyboard moved"
        appState.fingerCalibrationStatus = "Keyboard moved"
    }

    func moveSelectedKey(by translation: CGSize) {
        guard let keyID = selectedKeyID, var calibration = activeCalibration else { return }
        var adjustment = calibration.keyAdjustments[keyID] ?? .zero
        adjustment.offsetX += translation.width
        adjustment.offsetY += translation.height
        calibration.keyAdjustments[keyID] = adjustment
        activeCalibration = calibration
        calibrationStatus = "Updated offset for \(keyID)"
        appState.fingerCalibrationStatus = "Updated offset for \(keyID)"
    }

    func resetKey(_ keyID: String) {
        guard var calibration = activeCalibration else { return }
        calibration.keyAdjustments[keyID] = nil
        activeCalibration = calibration
        if selectedKeyID == keyID {
            selectedKeyLabel = KeyboardCalibrationLayout.definition(for: keyID)?.label
        }
        calibrationStatus = "Reset key adjustment"
        appState.fingerCalibrationStatus = "Reset key adjustment"
    }

    func resetCalibration() {
        guard let existing = activeCalibration else { return }
        activeCalibration = FingerCalibration.makeDefault(
            name: existing.name,
            imageSize: existing.imageSize.size,
            id: existing.id
        )
        selectedKeyID = nil
        selectedKeyLabel = nil
        draftCalibrationName = activeCalibration?.name ?? ""
        calibrationStatus = "Reset calibration"
        appState.fingerCalibrationStatus = "Reset calibration"
    }

    func saveCalibration() {
        guard var calibration = activeCalibration else {
            calibrationStatus = "No active calibration"
            return
        }

        let trimmedName = draftCalibrationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            calibrationStatus = "Calibration name required"
            appState.fingerCalibrationStatus = "Calibration name required"
            return
        }

        calibration.name = trimmedName
        calibration.updatedAt = Date()
        activeCalibration = calibration

        do {
            try store.save(calibration)
            refreshSavedCalibrations()
            let message = "Saved calibration: \(calibration.name)"
            calibrationStatus = message
            appState.fingerCalibrationStatus = message
        } catch {
            let message = "Failed to save calibration: \(error.localizedDescription)"
            calibrationStatus = message
            appState.fingerCalibrationStatus = message
        }
    }

    func loadCalibration(id: UUID) {
        do {
            let calibration = try store.load(id: id)
            activeCalibration = calibration
            draftCalibrationName = calibration.name
            selectedKeyID = nil
            selectedKeyLabel = nil
            let message = "Loaded calibration: \(calibration.name)"
            calibrationStatus = message
            appState.fingerCalibrationStatus = message
        } catch {
            let message = "Failed to load calibration"
            calibrationStatus = message
            appState.fingerCalibrationStatus = message
        }
    }

    func loadCalibration(_ summary: SavedCalibrationSummary) {
        loadCalibration(id: summary.id)
    }

    func deleteCalibration(_ id: UUID) {
        do {
            try store.delete(id: id)
            refreshSavedCalibrations()
            let message = "Deleted calibration"
            calibrationStatus = message
            appState.fingerCalibrationStatus = message
            if activeCalibration?.id == id {
                activeCalibration = FingerCalibration.makeDefault(name: "Untitled Calibration")
                draftCalibrationName = activeCalibration?.name ?? ""
                selectedKeyID = nil
                selectedKeyLabel = nil
            }
        } catch {
            let message = "Failed to delete calibration"
            calibrationStatus = message
            appState.fingerCalibrationStatus = message
        }
    }

    func refreshSavedCalibrations() {
        do {
            savedCalibrations = try store.listSummaries()
        } catch {
            savedCalibrations = []
            let message = "Failed to refresh saved calibrations"
            calibrationStatus = message
            appState.fingerCalibrationStatus = message
        }
    }

    func activeCalibrationNameOrFallback() -> String {
        activeCalibration?.name ?? ""
    }

    func receive(trackedFrame: TrackedFrame) {
        handleTrackedFrame(trackedFrame)
    }

    func receive(capturedFrame: CapturedFrame) {
        handleCapturedFrame(capturedFrame)
    }

    private func handleTrackedFrame(_ trackedFrame: TrackedFrame) {
        recentTrackedFrames.append(trackedFrame)
        if recentTrackedFrames.count > maxFrameHistory {
            recentTrackedFrames.removeFirst(recentTrackedFrames.count - maxFrameHistory)
        }
        trackingStatus = trackedFrame.backendStatus
    }

    private func handleCapturedFrame(_ frame: CapturedFrame) {
        guard !isFrozen else { return }

        liveFrame = frame.image
        let trackedFrame = handTrackingService.track(frame: frame)
        handleTrackedFrame(trackedFrame)
    }
}
