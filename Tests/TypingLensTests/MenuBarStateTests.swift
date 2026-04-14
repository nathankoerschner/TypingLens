import XCTest
@testable import TypingLens

final class MenuBarStateTests: XCTestCase {
    func testBlockedPermissionStateUsesBlockedStatusTitleAndLeavesEnableAvailable() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .notGranted,
            loggingStatus: .blocked(reason: "Permission required"),
            launchAtLoginEnabled: false
        )

        let state = MenuBarState(appState: appState)

        XCTAssertEqual(state.statusTitle, "Status: Blocked – Permission required")
        XCTAssertTrue(state.enableLoggingEnabled)
        XCTAssertFalse(state.disableLoggingEnabled)
        XCTAssertTrue(state.showOpenSystemSettings)
    }

    func testErrorStatusDoesNotShowSystemSettingsActionByDefault() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .granted,
            loggingStatus: .error(message: "Disk full"),
            launchAtLoginEnabled: false
        )

        let state = MenuBarState(appState: appState)

        XCTAssertEqual(state.statusTitle, "Status: Error – Disk full")
        XCTAssertEqual(state.errorMessage, "Disk full")
        XCTAssertFalse(state.showOpenSystemSettings)
    }

    func testEnabledLoggingDisablesEnableActionAndEnablesDisableAction() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .granted,
            loggingStatus: .enabled,
            launchAtLoginEnabled: false
        )

        let state = MenuBarState(appState: appState)

        XCTAssertEqual(state.statusTitle, "Status: Enabled")
        XCTAssertFalse(state.enableLoggingEnabled)
        XCTAssertTrue(state.disableLoggingEnabled)
    }
}
