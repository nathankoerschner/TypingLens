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

    private let store: FingerCalibrationStore
    private let appState: AppState

    @Published private(set) var canvasSize: CGSize = CGSize(width: 1_000, height: 620)

    init(
        appState: AppState,
        store: FingerCalibrationStore = FingerCalibrationStore(fileLocations: FileLocations()),
        defaultCalibration: FingerCalibration = FingerCalibration.makeDefault(name: "Untitled Calibration")
    ) {
        self.appState = appState
        self.store = store
        self.activeCalibration = defaultCalibration
        self.draftCalibrationName = defaultCalibration.name
        self.selectedKeyLabel = nil
        refreshSavedCalibrations()
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

    func freezeFrame() {
        isFrozen = true
        calibrationStatus = "Frame frozen for editing"
        appState.fingerCalibrationStatus = "Frame frozen for editing"
    }

    func resumeLiveFrame() {
        isFrozen = false
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
}
