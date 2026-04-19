import AppKit
import XCTest
@testable import TypingLens

final class SettingsSceneOpenerTests: XCTestCase {
    func testOpenSettingsInvokesInjectedAction() {
        let appState = AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .unknown,
            loggingStatus: .disabled,
            launchAtLoginEnabled: false
        )
        let transcriptWriter = NoopTranscriptWriter()
        var openSettingsRequests = 0
        let controller = MenuBarController(
            appState: appState,
            transcriptWriter: transcriptWriter,
            onOpenSettings: { openSettingsRequests += 1 },
            onOpenAnalytics: {},
            onPracticeNow: {},
            onOpenVisionTracking: {},
            loggingCoordinator: makeCoordinator(
                appState: appState,
                permissionManager: StubPermissionManager(status: .granted),
                transcriptWriter: NoopTranscriptWriter()
            ),
            permissionGuidancePresenter: NoopPermissionGuidancePresenter(),
            statusItem: FakeStatusItem()
        )

        controller.openSettings()

        XCTAssertEqual(openSettingsRequests, 1)
    }

    func testSwiftUISettingsSceneOpenerActivatesApplicationAndShowsInjectedSettingsWindow() {
        let application = RecordingApplication()
        let settingsWindow = RecordingSettingsWindow()
        let opener = SwiftUISettingsSceneOpener(
            application: application,
            settingsWindow: settingsWindow
        )

        opener.openSettingsScene()

        XCTAssertEqual(application.activationRequests, [true])
        XCTAssertEqual(settingsWindow.showRequests, 1)
        XCTAssertTrue(application.sentActions.isEmpty)
    }
}

private final class RecordingApplication: ApplicationOpening {
    private(set) var activationRequests: [Bool] = []
    private(set) var sentActions: [String] = []

    func activate(ignoringOtherApps flag: Bool) {
        activationRequests.append(flag)
    }

    func sendAction(_ action: Selector, to target: Any?, from sender: Any?) -> Bool {
        sentActions.append(NSStringFromSelector(action))
        return true
    }
}

private final class RecordingSettingsWindow: SettingsWindowShowing {
    private(set) var showRequests = 0

    func showSettingsWindow() {
        showRequests += 1
    }
}

private final class NoopTranscriptWriter: TranscriptWriting {
    func initializeNextSequence() throws -> Int64 { 1 }
    func append(_ event: TranscriptEvent) throws {}
    func clearTranscript() throws {}
    func revealInFinder() {}
}

private final class FakeStatusItem: MenuBarStatusItemPresenting {
    var button: NSStatusBarButton? = nil
    var menu: NSMenu?
}

private final class NoopPermissionGuidancePresenter: PermissionGuidancePresenting {
    func presentGuidance(openSystemSettings: @escaping () -> Void) {}
}

private func makeCoordinator(
    appState: AppState,
    permissionManager: PermissionManaging,
    transcriptWriter: TranscriptWriting
) -> LoggingCoordinator {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileLocations = FileLocations(appSupportBaseURL: tempDir)

    do {
        return try LoggingCoordinator(
            appState: appState,
            fileLocations: fileLocations,
            permissionManager: permissionManager,
            keyboardMonitor: StubKeyboardMonitor(),
            transcriptWriter: transcriptWriter
        )
    } catch {
        return LoggingCoordinator(
            appState: appState,
            fileLocations: fileLocations,
            permissionManager: permissionManager,
            keyboardMonitor: StubKeyboardMonitor(),
            transcriptWriter: transcriptWriter,
            initialSequence: 1
        )
    }
}

private final class StubPermissionManager: PermissionManaging {
    let status: AppState.PermissionStatus

    init(status: AppState.PermissionStatus) {
        self.status = status
    }

    func currentStatus() -> AppState.PermissionStatus { status }
    func refreshStatus() -> AppState.PermissionStatus { status }
    func openSystemSettings() {}
}

private final class StubKeyboardMonitor: KeyboardMonitoring {
    func start(handler: @escaping (NormalizedKeyEvent) -> Void) throws {}
    func stop() {}
}
