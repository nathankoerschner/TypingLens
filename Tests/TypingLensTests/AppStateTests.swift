import XCTest
@testable import TypingLens

final class AppStateTests: XCTestCase {
    func testInitialDerivedValuesReflectStatus() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .unknown,
            loggingStatus: .disabled,
            launchAtLoginEnabled: false
        )

        XCTAssertFalse(appState.isLoggingEnabled)
        XCTAssertNil(appState.currentErrorMessage)
        XCTAssertEqual(appState.transcriptPath, "/tmp/transcript.jsonl")
        XCTAssertEqual(appState.permissionStatus, .unknown)
    }

    func testCurrentErrorMessageIsProjectedFromLoggingStatus() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .unknown,
            loggingStatus: .error(message: "boom"),
            launchAtLoginEnabled: false
        )

        XCTAssertEqual(appState.currentErrorMessage, "boom")
    }

    func testEnabledStatusMarksLoggingAsEnabled() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .granted,
            loggingStatus: .enabled,
            launchAtLoginEnabled: true
        )

        XCTAssertTrue(appState.isLoggingEnabled)
    }

    func testApplyPermissionStatusBlocksActiveLoggingWhenPermissionIsLost() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .granted,
            loggingStatus: .enabled,
            launchAtLoginEnabled: false
        )

        appState.applyPermissionStatus(.notGranted)

        XCTAssertEqual(appState.permissionStatus, .notGranted)
        XCTAssertEqual(appState.loggingStatus, .blocked(reason: "Permission required"))
    }

    func testClearRecoverableRuntimeErrorRestoresDisabledState() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .granted,
            loggingStatus: .error(message: "boom"),
            launchAtLoginEnabled: false
        )

        appState.clearRuntimeErrorIfRecoverable()

        XCTAssertEqual(appState.loggingStatus, .disabled)
    }
}
