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
        appState.extractionStatus = "Extracted 5 words"
        appState.rankedExportStatus = "Ranked 3 unique words"
        appState.practiceStatus = "No words available for practice"
        appState.analyticsStatus = "No analytics available yet"

        let state = viewModel.state(for: appState)

        XCTAssertEqual(state.permissionStatus, "Granted")
        XCTAssertEqual(state.loggingStatus, "Error – Disk full")
        XCTAssertEqual(state.launchAtLoginEnabled, true)
        XCTAssertEqual(state.currentErrorMessage, "Disk full")
        XCTAssertEqual(state.transcriptPath, "/tmp/transcript.jsonl")
        XCTAssertEqual(state.extractionStatus, "Extracted 5 words")
        XCTAssertEqual(state.rankedExportStatus, "Ranked 3 unique words")
        XCTAssertEqual(state.practiceStatus, "No words available for practice")
        XCTAssertEqual(state.analyticsStatus, "No analytics available yet")
    }

    func testActionCallbacksAreForwarded() {
        var didRefresh = false
        var didOpenSystemSettings = false
        var didReveal = false
        var didClear = false
        var didToggle: Bool?
        var didExtractWords = false
        var didExportRankedWords = false
        var didPracticeNow = false
        var didOpenAnalytics = false

        let viewModel = SettingsViewModel(
            onRefreshPermissionStatus: { didRefresh = true },
            onOpenSystemSettings: { didOpenSystemSettings = true },
            onRevealTranscript: { didReveal = true },
            onClearTranscript: { didClear = true },
            onToggleLaunchAtLogin: { didToggle = $0 },
            onExtractWords: { didExtractWords = true },
            onExportRankedWords: { didExportRankedWords = true },
            onPracticeNow: { didPracticeNow = true },
            onOpenAnalytics: { didOpenAnalytics = true }
        )

        viewModel.refreshPermissionStatus()
        viewModel.openSystemSettings()
        viewModel.revealTranscript()
        viewModel.clearTranscript()
        viewModel.toggleLaunchAtLogin(false)
        viewModel.extractWords()
        viewModel.exportRankedWords()
        viewModel.practiceNow()
        viewModel.openAnalytics()

        XCTAssertTrue(didRefresh)
        XCTAssertTrue(didOpenSystemSettings)
        XCTAssertTrue(didReveal)
        XCTAssertTrue(didClear)
        XCTAssertEqual(didToggle, false)
        XCTAssertTrue(didExtractWords)
        XCTAssertTrue(didExportRankedWords)
        XCTAssertTrue(didPracticeNow)
        XCTAssertTrue(didOpenAnalytics)
    }

    private func makeViewModel() -> SettingsViewModel {
        SettingsViewModel(
            onRefreshPermissionStatus: {},
            onOpenSystemSettings: {},
            onRevealTranscript: {},
            onClearTranscript: {},
            onToggleLaunchAtLogin: { _ in },
            onExtractWords: {},
            onExportRankedWords: {},
            onPracticeNow: {},
            onOpenAnalytics: {}
        )
    }
}
