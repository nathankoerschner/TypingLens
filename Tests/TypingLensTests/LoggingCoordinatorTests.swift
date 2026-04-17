import XCTest
@testable import TypingLens

final class LoggingCoordinatorTests: XCTestCase {
    func testEnableRequestWithoutPermissionSetsBlockedState() {
        let appState = makeAppState()
        let permissionManager = StubPermissionManager(status: .notGranted)
        let monitor = StubKeyboardMonitor()
        let writer = StubTranscriptWriter()

        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: writer
        )

        let didEnable = coordinator.enableLoggingRequested()

        XCTAssertFalse(didEnable)
        XCTAssertEqual(appState.permissionStatus, .notGranted)
        XCTAssertEqual(appState.loggingStatus, .blocked(reason: "Grant permission in System Settings"))
        XCTAssertFalse(monitor.startCalled)
    }

    func testEnableRequestWithPermissionStartsMonitoringAndEnablesLogging() {
        let appState = makeAppState()
        let permissionManager = StubPermissionManager(status: .granted)
        let monitor = StubKeyboardMonitor()
        let writer = StubTranscriptWriter()
        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: writer
        )

        let didEnable = coordinator.enableLoggingRequested()

        XCTAssertTrue(didEnable)
        XCTAssertEqual(appState.permissionStatus, .granted)
        XCTAssertEqual(appState.loggingStatus, .enabled)
        XCTAssertTrue(monitor.startCalled)
    }

    func testEnableRequestWithPermissionPersistsNormalizedEventIntoTranscript() {
        let appState = makeAppState()
        let permissionManager = StubPermissionManager(status: .granted)
        let monitor = StubKeyboardMonitor()
        let writer = SpyTranscriptWriter()
        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: writer
        )

        XCTAssertTrue(coordinator.enableLoggingRequested())

        monitor.emit(
            .init(
                type: .keyDown,
                keyCode: 0,
                characters: "A",
                charactersIgnoringModifiers: "a",
                modifiers: ["shift"],
                isRepeat: false,
                keyboardLayout: nil
            )
        )

        let event = try! XCTUnwrap(writer.appendedEvents.first)
        XCTAssertEqual(event.seq, 1)
        XCTAssertEqual(event.type, .keyDown)
        XCTAssertEqual(event.keyCode, 0)
        XCTAssertEqual(event.characters, "A")
        XCTAssertEqual(event.charactersIgnoringModifiers, "a")
        XCTAssertEqual(event.modifiers, ["shift"])
        XCTAssertFalse(event.isRepeat)
    }

    func testSequenceIncrementOnlyAfterSuccessfulWrites() {
        let appState = makeAppState()
        let permissionManager = StubPermissionManager(status: .granted)
        let monitor = StubKeyboardMonitor()
        let writer = SpyTranscriptWriter(shouldFailNextAppend: false)
        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: writer
        )

        XCTAssertTrue(coordinator.enableLoggingRequested())
        monitor.emit(sampleNormalizedEvent(seq: 1))
        writer.shouldFailNextAppend = true
        monitor.emit(sampleNormalizedEvent(seq: 2))

        XCTAssertEqual(writer.appendedEvents.map(\.seq), [1])
        XCTAssertEqual(appState.loggingStatus, .error(message: "Unable to write transcript: Transcript append failed: write fail"))
        XCTAssertTrue(monitor.stopCalled)

        coordinator.enableLoggingRequested()
        writer.shouldFailNextAppend = false
        monitor.emit(sampleNormalizedEvent(seq: 3))

        XCTAssertEqual(writer.appendedEvents.map(\.seq), [1, 2])
    }

    func testDisableRequestStopsMonitoringAndDisablesState() {
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
            transcriptWriter: StubTranscriptWriter()
        )

        coordinator.disableLoggingRequested()

        XCTAssertEqual(appState.loggingStatus, .disabled)
    }

    func testRefreshPermissionStatusAppliesCurrentPermissionState() {
        let appState = makeAppState()
        let permissionManager = StubPermissionManager(status: .needsRetry)
        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: StubKeyboardMonitor(),
            transcriptWriter: StubTranscriptWriter()
        )

        coordinator.refreshPermissionStatus()

        XCTAssertEqual(appState.permissionStatus, .needsRetry)
    }

    func testMakePracticePromptGeneratesPromptFromTranscript() {
        let appState = makeAppState()
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let coordinator = makeCoordinatorWithTranscript(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: StubTranscriptWriter(),
            transcriptEvents: samplePracticeEvents()
        )

        let prompt = coordinator.makePracticePrompt()

        XCTAssertEqual(prompt?.words.count, 50)
        XCTAssertNil(appState.practiceStatus)
    }

    func testPracticeNowUsesCorrectedWordsInPrompt() {
        let appState = makeAppState()
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let coordinator = makeCoordinatorWithTranscript(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: StubTranscriptWriter(),
            transcriptEvents: transcriptEvents(for: ["teh", "the", "teh"])
        )

        let prompt = coordinator.makePracticePrompt()

        XCTAssertNotNil(prompt)
        XCTAssertFalse(prompt!.words.isEmpty)
        XCTAssertTrue(prompt!.words.allSatisfy { $0 == "the" })
    }

    func testPracticeNowDropsUnknownTokensBeforePromptBuild() {
        let appState = makeAppState()
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let coordinator = makeCoordinatorWithTranscript(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: StubTranscriptWriter(),
            transcriptEvents: transcriptEvents(for: ["xqplm", "jjjjkjj"])
        )

        let prompt = coordinator.makePracticePrompt()

        XCTAssertNil(prompt)
        XCTAssertEqual(appState.practiceStatus, "No words available for practice")
    }

    func testPracticeNowSetsEmptyStatusWhenNoWordsExist() {
        let appState = makeAppState()
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let coordinator = makeCoordinatorWithTranscript(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: StubTranscriptWriter(),
            transcriptEvents: sampleWhitespaceEvents()
        )

        let prompt = coordinator.makePracticePrompt()

        XCTAssertNil(prompt)
        XCTAssertEqual(appState.practiceStatus, "No words available for practice")
    }

    func testPracticeNowSetsFailureStatusWhenTranscriptIsMissing() {
        let appState = makeAppState()
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: StubTranscriptWriter()
        )

        let prompt = coordinator.makePracticePrompt()

        XCTAssertNil(prompt)
        XCTAssertEqual(appState.practiceStatus, "Practice generation failed: Transcript file not found.")
    }

    func testMakeAnalyticsResultReturnsResultsWhenTranscriptHasRows() {
        let appState = makeAppState()
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let coordinator = makeCoordinatorWithTranscript(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: StubTranscriptWriter(),
            transcriptEvents: transcriptEvents(for: ["hello", "world"])
        )

        let result = coordinator.makeAnalyticsResult()

        XCTAssertEqual(result?.totalUniqueWords, 2)
        XCTAssertNil(appState.analyticsStatus)
        XCTAssertGreaterThan(result?.totalUniqueWords ?? 0, 0)
    }

    func testMakeAnalyticsResultForEmptyTranscriptReturnsEmptyResult() {
        let appState = makeAppState()
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let coordinator = makeCoordinatorWithTranscript(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: StubTranscriptWriter(),
            transcriptEvents: sampleWhitespaceEvents()
        )

        let result = coordinator.makeAnalyticsResult()

        XCTAssertEqual(result?.totalUniqueWords, 0)
        XCTAssertEqual(result?.words.count, 0)
        XCTAssertEqual(appState.analyticsStatus, "No analytics available yet")
    }

    func testMakeAnalyticsResultSetsFailureStatusWhenTranscriptMissing() {
        let appState = makeAppState()
        let monitor = StubKeyboardMonitor()
        let permissionManager = StubPermissionManager(status: .granted)
        let coordinator = makeCoordinator(
            appState: appState,
            permissionManager: permissionManager,
            keyboardMonitor: monitor,
            transcriptWriter: StubTranscriptWriter()
        )

        let result = coordinator.makeAnalyticsResult()

        XCTAssertNil(result)
        XCTAssertEqual(appState.analyticsStatus, "Analytics generation failed: Transcript file not found.")
    }

    private func makeCoordinatorWithTranscript(
        appState: AppState,
        permissionManager: PermissionManaging,
        keyboardMonitor: StubKeyboardMonitor,
        transcriptWriter: TranscriptWriting,
        transcriptEvents: [TranscriptEvent]
    ) -> LoggingCoordinator {
        do {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let fileLocations = FileLocations(appSupportBaseURL: tempDir)
            try createTranscript(at: fileLocations, events: transcriptEvents)

            return try LoggingCoordinator(
                appState: appState,
                fileLocations: fileLocations,
                permissionManager: permissionManager,
                keyboardMonitor: keyboardMonitor,
                transcriptWriter: transcriptWriter
            )
        } catch {
            fatalError("Unexpected coordinator initialization failure: \(error.localizedDescription)")
        }
    }

    private func makeCoordinator(
        appState: AppState,
        permissionManager: PermissionManaging,
        keyboardMonitor: StubKeyboardMonitor,
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
                keyboardMonitor: keyboardMonitor,
                transcriptWriter: transcriptWriter
            )
        } catch {
            XCTFail("Unexpected coordinator initialization failure: \(error.localizedDescription)")
            return LoggingCoordinator(
                appState: appState,
                fileLocations: fileLocations,
                permissionManager: permissionManager,
                keyboardMonitor: keyboardMonitor,
                transcriptWriter: transcriptWriter,
                initialSequence: 1
            )
        }
    }

    private func createTranscript(at fileLocations: FileLocations, events: [TranscriptEvent]) throws {
        try FileManager.default.createDirectory(at: fileLocations.appDirectoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder.transcriptEncoder()
        let lines = try events.map { event in
            let data = try encoder.encode(event)
            return String(data: data, encoding: .utf8)!
        }

        let content = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        try content.write(to: fileLocations.transcriptURL, atomically: true, encoding: .utf8)
    }

    private func makeAppState() -> AppState {
        AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .unknown,
            loggingStatus: .disabled,
            launchAtLoginEnabled: false
        )
    }

    private func sampleNormalizedEvent(seq _: Int64) -> NormalizedKeyEvent {
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

    private func samplePracticeEvents() -> [TranscriptEvent] {
        var seq: Int64 = 1
        let timestamp = "2026-04-14T12:00:00.000000Z"

        func keyDown(_ char: String) -> TranscriptEvent {
            defer { seq += 1 }
            return TranscriptEvent(
                seq: seq,
                ts: timestamp,
                type: .keyDown,
                keyCode: 0,
                characters: char,
                charactersIgnoringModifiers: char,
                modifiers: [],
                isRepeat: false,
                keyboardLayout: nil
            )
        }

        return "hello".map { keyDown(String($0)) } + [keyDown(" ")] +
            "world".map { keyDown(String($0)) } + [keyDown(" ")]
    }

    private func transcriptEvents(for words: [String]) -> [TranscriptEvent] {
        var seq: Int64 = 0
        var timeOffset: Double = 0
        let baseTime = Date(timeIntervalSince1970: 1_000_000)

        func next() -> Int64 { seq += 1; return seq }
        func ts() -> String {
            timeOffset += 0.05
            return TimestampFormatter.string(from: baseTime.addingTimeInterval(timeOffset))
        }

        func keyDown(_ char: String) -> TranscriptEvent {
            TranscriptEvent(
                seq: next(),
                ts: ts(),
                type: .keyDown,
                keyCode: 0,
                characters: char,
                charactersIgnoringModifiers: char,
                modifiers: [],
                isRepeat: false,
                keyboardLayout: nil
            )
        }

        var events: [TranscriptEvent] = []
        for word in words {
            events += word.map { keyDown(String($0)) }
            events.append(keyDown(" "))
        }

        return events
    }

    private func sampleWhitespaceEvents() -> [TranscriptEvent] {
        return [
            TranscriptEvent(
                seq: 1,
                ts: "2026-04-14T12:00:00.000000Z",
                type: .keyDown,
                keyCode: 0,
                characters: " ",
                charactersIgnoringModifiers: " ",
                modifiers: [],
                isRepeat: false,
                keyboardLayout: nil
            )
        ]
    }
}

private final class StubPermissionManager: PermissionManaging {
    var status: AppState.PermissionStatus

    init(status: AppState.PermissionStatus) {
        self.status = status
    }

    func currentStatus() -> AppState.PermissionStatus { status }
    func refreshStatus() -> AppState.PermissionStatus { status }
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

private final class SpyTranscriptWriter: TranscriptWriting {
    private(set) var appendedEvents: [TranscriptEvent] = []
    var shouldFailNextAppend = false

    init(shouldFailNextAppend: Bool = false) {
        self.shouldFailNextAppend = shouldFailNextAppend
    }

    func initializeNextSequence() throws -> Int64 { 1 }

    func append(_ event: TranscriptEvent) throws {
        if shouldFailNextAppend {
            shouldFailNextAppend = false
            throw TranscriptWriterError.appendFailed("write fail")
        }
        appendedEvents.append(event)
    }

    func clearTranscript() throws {}
    func revealInFinder() {}
}
