import Foundation
import XCTest
@testable import TypingLens

final class ErrorStateTests: XCTestCase {
    func testMenuBarStateExposesErrorCopyForErrorStatus() {
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

    func testRefreshPermissionStatusClearsBlockedStateWhenPermissionIsRecovered() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .notGranted,
            loggingStatus: .blocked(reason: "Permission required"),
            launchAtLoginEnabled: false
        )

        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: StubPermissionManager(status: .granted),
            keyboardMonitor: StubKeyboardMonitor(),
            transcriptWriter: StubTranscriptWriter()
        )

        coordinator.refreshPermissionStatus()

        XCTAssertEqual(appState.loggingStatus, .disabled)
        XCTAssertEqual(appState.permissionStatus, .granted)
    }

    func testClearTranscriptFailureSurfacesErrorState() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .granted,
            loggingStatus: .enabled,
            launchAtLoginEnabled: false
        )

        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: StubPermissionManager(status: .granted),
            keyboardMonitor: StubKeyboardMonitor(),
            transcriptWriter: FailingTranscriptWriterForClear()
        )

        XCTAssertFalse(coordinator.clearTranscriptRequested())

        switch appState.loggingStatus {
        case let .error(message):
            XCTAssertTrue(message.hasPrefix("Unable to clear transcript: "))
        default:
            XCTFail("Expected error state after failed clear")
        }
    }

    private func makeCoordinator(
        appState: AppState,
        permissionManager: PermissionManaging,
        keyboardMonitor: StubKeyboardMonitor,
        transcriptWriter: TranscriptWriting
    ) -> LoggingCoordinator {
        do {
            return try LoggingCoordinator(
                appState: appState,
                permissionManager: permissionManager,
                keyboardMonitor: keyboardMonitor,
                transcriptWriter: transcriptWriter
            )
        } catch {
            XCTFail("Unexpected coordinator initialization failure: \(error.localizedDescription)")
            return LoggingCoordinator(
                appState: appState,
                permissionManager: permissionManager,
                keyboardMonitor: keyboardMonitor,
                transcriptWriter: transcriptWriter,
                initialSequence: 1
            )
        }
    }
}

private final class StubPermissionManager: PermissionManaging {
    var status: AppState.PermissionStatus

    init(status: AppState.PermissionStatus) {
        self.status = status
    }

    func currentStatus() -> AppState.PermissionStatus {
        status
    }

    func refreshStatus() -> AppState.PermissionStatus {
        status
    }

    func openSystemSettings() {}
}

private final class StubKeyboardMonitor: KeyboardMonitoring {
    func start(handler: @escaping (NormalizedKeyEvent) -> Void) throws {
        _ = handler
    }

    func stop() {}
}

private final class StubTranscriptWriter: TranscriptWriting {
    func initializeNextSequence() throws -> Int64 { 1 }
    func append(_ event: TranscriptEvent) throws {}
    func clearTranscript() throws {}
    func revealInFinder() {}
}

private final class FailingTranscriptWriterForClear: TranscriptWriting {
    func initializeNextSequence() throws -> Int64 { 1 }

    func append(_ event: TranscriptEvent) throws {}

    func clearTranscript() throws {
        throw TranscriptWriterError.failedToCreateTranscript
    }

    func revealInFinder() {}
}
