import Foundation
import XCTest
@testable import TypingLens

@MainActor
final class FingerCalibrationViewModelTests: XCTestCase {
    func testFreezeAndResumeUpdateStatus() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.isFrozen)

        viewModel.freezeFrame()
        XCTAssertTrue(viewModel.isFrozen)
        XCTAssertEqual(viewModel.calibrationStatus, "Frame frozen for editing")

        viewModel.resumeLiveFrame()
        XCTAssertFalse(viewModel.isFrozen)
        XCTAssertEqual(viewModel.calibrationStatus, "Live frame editing resumed")
    }

    func testSaveLoadRoundTripsThroughStoreAndRestoreAdjustments() throws {
        let appState = makeAppState()
        let fileLocations = FileLocations(appSupportBaseURL: temporaryDirectory())
        let store = FingerCalibrationStore(fileLocations: fileLocations)
        defer { cleanupDirectory(at: fileLocations.appSupportBaseURL) }

        let viewModel = makeViewModel(appState: appState, store: store)
        viewModel.selectKey("A")
        viewModel.moveSelectedKey(by: CGSize(width: 4, height: 6))
        viewModel.draftCalibrationName = "Office"
        viewModel.saveCalibration()

        guard let saved = viewModel.savedCalibrations.first(where: { $0.name == "Office" }) else {
            return XCTFail("Expected saved calibration")
        }

        let reload = makeViewModel(appState: appState, store: store)
        reload.loadCalibration(id: saved.id)

        XCTAssertEqual(reload.activeCalibration?.name, "Office")
        XCTAssertEqual(reload.activeCalibration?.keyAdjustments["A"], KeyAdjustment(offsetX: 4, offsetY: 6))
        XCTAssertNil(reload.selectedKeyID)
    }

    func testResetCalibrationClearsAdjustmentsAndResetsSelection() {
        let viewModel = makeViewModel()
        viewModel.selectKey("S")
        viewModel.moveSelectedKey(by: CGSize(width: 5, height: -2))

        XCTAssertEqual(viewModel.activeCalibration?.keyAdjustments["S"], KeyAdjustment(offsetX: 5, offsetY: -2))

        viewModel.resetKey("S")
        XCTAssertNil(viewModel.activeCalibration?.keyAdjustments["S"])
    }

    func testDeleteCalibrationRemovesFromSavedList() throws {
        let appState = makeAppState()
        let fileLocations = FileLocations(appSupportBaseURL: temporaryDirectory())
        let store = FingerCalibrationStore(fileLocations: fileLocations)
        defer { cleanupDirectory(at: fileLocations.appSupportBaseURL) }

        let viewModel = makeViewModel(appState: appState, store: store)
        viewModel.draftCalibrationName = "To Delete"
        viewModel.saveCalibration()

        guard let saved = viewModel.savedCalibrations.first(where: { $0.name == "To Delete" }) else {
            return XCTFail("Expected saved calibration")
        }

        viewModel.deleteCalibration(saved.id)

        XCTAssertFalse(viewModel.savedCalibrations.contains(where: { $0.id == saved.id }))
    }

    private func makeViewModel(
        appState: AppState,
        store: FingerCalibrationStore
    ) -> FingerCalibrationViewModel {
        FingerCalibrationViewModel(appState: appState, store: store)
    }

    private func makeViewModel() -> FingerCalibrationViewModel {
        makeViewModel(appState: makeAppState(), store: defaultStore())
    }

    private func defaultStore() -> FingerCalibrationStore {
        FingerCalibrationStore(fileLocations: FileLocations(appSupportBaseURL: temporaryDirectory()))
    }

    private func makeAppState() -> AppState {
        AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .unknown,
            loggingStatus: .disabled,
            launchAtLoginEnabled: false
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("FingerCalibrationViewModelTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
    }

    private func cleanupDirectory(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
