import XCTest
@testable import TypingLens

final class SettingsViewModelTests: XCTestCase {
    func testStateMapsAppStateToHumanReadableValues() {
        let viewModel = makeViewModel()
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .granted,
            loggingStatus: .error(message: "Disk full"),
            launchAtLoginEnabled: true
        )

        let state = viewModel.state(for: appState)

        XCTAssertEqual(state.permissionStatus, "Granted")
        XCTAssertEqual(state.loggingStatus, "Error – Disk full")
        XCTAssertEqual(state.launchAtLoginEnabled, true)
        XCTAssertEqual(state.currentErrorMessage, "Disk full")
        XCTAssertEqual(state.transcriptPath, "/tmp/transcript.jsonl")
    }

    func testActionCallbacksAreForwarded() {
        var didRefresh = false
        var didOpenSystemSettings = false
        var didReveal = false
        var didClear = false
        var didToggle: Bool?

        let viewModel = SettingsViewModel(
            onRefreshPermissionStatus: { didRefresh = true },
            onOpenSystemSettings: { didOpenSystemSettings = true },
            onRevealTranscript: { didReveal = true },
            onClearTranscript: { didClear = true },
            onToggleLaunchAtLogin: { didToggle = $0 }
        )

        viewModel.refreshPermissionStatus()
        viewModel.openSystemSettings()
        viewModel.revealTranscript()
        viewModel.clearTranscript()
        viewModel.toggleLaunchAtLogin(false)

        XCTAssertTrue(didRefresh)
        XCTAssertTrue(didOpenSystemSettings)
        XCTAssertTrue(didReveal)
        XCTAssertTrue(didClear)
        XCTAssertEqual(didToggle, false)
    }

    private func makeViewModel() -> SettingsViewModel {
        SettingsViewModel(
            onRefreshPermissionStatus: {},
            onOpenSystemSettings: {},
            onRevealTranscript: {},
            onClearTranscript: {},
            onToggleLaunchAtLogin: { _ in }
        )
    }
}
