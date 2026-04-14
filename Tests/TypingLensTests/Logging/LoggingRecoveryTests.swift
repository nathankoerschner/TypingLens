import Foundation
import XCTest
@testable import TypingLens

final class LoggingRecoveryTests: XCTestCase {
    func testAppendAfterDeletedTranscriptRecreatesFile() throws {
        let tempDir = try temporaryDirectory()
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let writer = TranscriptWriter(fileLocations: locations)
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let appState = makeAppState()

        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: writer
        )

        XCTAssertTrue(coordinator.enableLoggingRequested())
        try FileManager.default.removeItem(at: locations.transcriptURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: locations.transcriptURL.path))

        monitor.emit(sampleNormalizedEvent())

        let events = try readEvents(from: locations)
        XCTAssertEqual(events.map(\.seq), [1])
        XCTAssertEqual(appState.loggingStatus, .enabled)
    }

    func testAppendFailureStopsLoggingAndSurfacesReadableError() {
        let writer = FailingTranscriptWriter(shouldFailAppend: true)
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let appState = makeAppState()
        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: writer
        )

        XCTAssertTrue(coordinator.enableLoggingRequested())
        monitor.emit(sampleNormalizedEvent())

        XCTAssertEqual(appState.loggingStatus, .error(message: "Unable to write transcript: Transcript append failed: write fail"))
        XCTAssertTrue(monitor.stopCalled)
        XCTAssertTrue(writer.didAttemptAppend)
    }

    func testPermissionRevocationStopsLoggingWhenAppBecomesActive() {
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let appState = makeAppState()
        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: StubTranscriptWriter()
        )

        XCTAssertTrue(coordinator.enableLoggingRequested())
        XCTAssertEqual(appState.loggingStatus, .enabled)

        permissionManager.status = .notGranted
        coordinator.handleAppDidBecomeActive()

        XCTAssertEqual(appState.permissionStatus, .notGranted)
        XCTAssertEqual(appState.loggingStatus, .blocked(reason: "Permission was revoked"))
        XCTAssertTrue(monitor.stopCalled)
    }

    func testClearTranscriptResetsSequenceForSubsequentWrites() throws {
        let tempDir = try temporaryDirectory()
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let writer = TranscriptWriter(fileLocations: locations)
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let appState = makeAppState()

        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: writer
        )

        XCTAssertTrue(coordinator.enableLoggingRequested())
        monitor.emit(sampleNormalizedEvent())

        XCTAssertTrue(coordinator.clearTranscriptRequested())
        XCTAssertEqual(try Data(contentsOf: locations.transcriptURL).count, 0)

        monitor.emit(sampleNormalizedEvent())
        let events = try readEvents(from: locations)
        XCTAssertEqual(events.map(\.seq), [1])
    }

    func testSequenceContinuesAcrossRelaunchFromPersistedTail() throws {
        let tempDir = try temporaryDirectory()
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let firstWriter = TranscriptWriter(fileLocations: locations)
        let firstMonitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let appState = makeAppState()

        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: firstMonitor,
            transcriptWriter: firstWriter
        )

        XCTAssertTrue(coordinator.enableLoggingRequested())
        firstMonitor.emit(sampleNormalizedEvent())
        firstMonitor.emit(sampleNormalizedEvent())

        let firstSessionEvents = try readEvents(from: locations)
        XCTAssertEqual(firstSessionEvents.map(\.seq), [1, 2])

        let secondWriter = TranscriptWriter(fileLocations: locations)
        let secondMonitor = StubKeyboardMonitor()
        let secondCoordinator = makeCoordinator(
            appState: makeAppState(),
            permissionManager: permissionManager,
            keyboardMonitor: secondMonitor,
            transcriptWriter: secondWriter
        )

        XCTAssertTrue(secondCoordinator.enableLoggingRequested())
        secondMonitor.emit(sampleNormalizedEvent())

        let relaunchEvents = try readEvents(from: locations)
        XCTAssertEqual(relaunchEvents.map(\.seq), [1, 2, 3])
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

    private func makeAppState() -> AppState {
        AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .granted,
            loggingStatus: .disabled,
            launchAtLoginEnabled: false
        )
    }

    private func sampleNormalizedEvent() -> NormalizedKeyEvent {
        .init(
            type: .keyDown,
            keyCode: 0,
            characters: "A",
            charactersIgnoringModifiers: "a",
            modifiers: ["shift"],
            isRepeat: false,
            keyboardLayout: nil
        )
    }

    private func temporaryDirectory() throws -> URL {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }

    private func readEvents(from locations: FileLocations) throws -> [TranscriptEvent] {
        let data = try Data(contentsOf: locations.transcriptURL)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        let lines = text.split(separator: "\n")

        return try lines.map {
            try JSONDecoder().decode(TranscriptEvent.self, from: Data(String($0).utf8))
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
    private(set) var startCalled = false
    private(set) var stopCalled = false
    private var handler: ((NormalizedKeyEvent) -> Void)?

    func start(handler: @escaping (NormalizedKeyEvent) -> Void) throws {
        startCalled = true
        self.handler = handler
    }

    func stop() {
        stopCalled = true
        handler = nil
    }

    func emit(_ event: NormalizedKeyEvent) {
        handler?(event)
    }
}

private final class StubTranscriptWriter: TranscriptWriting {
    func initializeNextSequence() throws -> Int64 { 1 }
    func append(_ event: TranscriptEvent) throws {}
    func clearTranscript() throws {}
    func revealInFinder() {}
}

private final class FailingTranscriptWriter: TranscriptWriting {
    private(set) var didAttemptAppend = false
    private let shouldFailAppend: Bool

    init(shouldFailAppend: Bool) {
        self.shouldFailAppend = shouldFailAppend
    }

    func initializeNextSequence() throws -> Int64 { 1 }

    func append(_ event: TranscriptEvent) throws {
        didAttemptAppend = true
        if shouldFailAppend {
            throw TranscriptWriterError.appendFailed("write fail")
        }
    }

    func clearTranscript() throws {}
    func revealInFinder() {}
}
