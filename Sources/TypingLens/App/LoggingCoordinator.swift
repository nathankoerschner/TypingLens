import Foundation

final class LoggingCoordinator {
    private let appState: AppState
    private let fileLocations: FileLocations
    private let permissionManager: PermissionManaging
    private let keyboardMonitor: KeyboardMonitoring
    private let transcriptWriter: TranscriptWriting
    private let onOpenPractice: (PracticePrompt) -> Void
    private var nextSeq: Int64 = 1

    init(
        appState: AppState,
        fileLocations: FileLocations,
        permissionManager: PermissionManaging,
        keyboardMonitor: KeyboardMonitoring,
        transcriptWriter: TranscriptWriting,
        onOpenPractice: @escaping (PracticePrompt) -> Void = { _ in }
    ) throws {
        self.appState = appState
        self.fileLocations = fileLocations
        self.permissionManager = permissionManager
        self.keyboardMonitor = keyboardMonitor
        self.transcriptWriter = transcriptWriter
        self.onOpenPractice = onOpenPractice
        self.nextSeq = try transcriptWriter.initializeNextSequence()
    }

    init(
        appState: AppState,
        fileLocations: FileLocations,
        permissionManager: PermissionManaging,
        keyboardMonitor: KeyboardMonitoring,
        transcriptWriter: TranscriptWriting,
        onOpenPractice: @escaping (PracticePrompt) -> Void = { _ in },
        initialSequence: Int64
    ) {
        self.appState = appState
        self.fileLocations = fileLocations
        self.permissionManager = permissionManager
        self.keyboardMonitor = keyboardMonitor
        self.transcriptWriter = transcriptWriter
        self.onOpenPractice = onOpenPractice
        self.nextSeq = initialSequence
    }

    func refreshPermissionStatus() {
        let status = permissionManager.refreshStatus()
        appState.applyPermissionStatus(status)
        recoverStateIfNeeded(for: status)
    }

    func handleAppDidBecomeActive() {
        let status = permissionManager.refreshStatus()
        let wasEnabled = appState.isLoggingEnabled
        appState.applyPermissionStatus(status)

        if status != .granted, wasEnabled {
            keyboardMonitor.stop()
            appState.loggingStatus = .blocked(reason: "Permission was revoked")
            return
        }

        recoverStateIfNeeded(for: status)
    }

    @discardableResult
    func enableLoggingRequested() -> Bool {
        let status = permissionManager.refreshStatus()
        appState.applyPermissionStatus(status)

        guard status == .granted else {
            appState.loggingStatus = .blocked(reason: "Grant permission in System Settings")
            return false
        }

        appState.clearRuntimeErrorIfRecoverable()

        do {
            try keyboardMonitor.start { [weak self] event in
                self?.handle(event)
            }
            appState.loggingStatus = .enabled
            return true
        } catch {
            appState.loggingStatus = .error(message: "Unable to start keyboard monitor: \(error.localizedDescription)")
            return false
        }
    }

    func disableLoggingRequested() {
        keyboardMonitor.stop()
        appState.loggingStatus = .disabled
    }

    @discardableResult
    func clearTranscriptRequested() -> Bool {
        do {
            try transcriptWriter.clearTranscript()
            nextSeq = 1
            appState.clearRuntimeErrorIfRecoverable()
            return true
        } catch {
            appState.loggingStatus = .error(message: "Unable to clear transcript: \(error.localizedDescription)")
            return false
        }
    }

    func extractWordsRequested() {
        let service = WordExtractionService(fileLocations: fileLocations)

        do {
            let result = try service.run()
            if result.totalWords == 0 {
                appState.extractionStatus = "No words found in transcript"
            } else {
                appState.extractionStatus = "Extracted \(result.totalWords) words to extracted-words.json"
            }
        } catch {
            appState.extractionStatus = "Extraction failed: \(error.localizedDescription)"
        }
    }

    func exportRankedWordsRequested() {
        let service = RankedExportService(fileLocations: fileLocations)

        do {
            let result = try service.run()
            if result.totalUniqueWords == 0 {
                appState.rankedExportStatus = "No words to rank in transcript"
            } else {
                appState.rankedExportStatus = "Ranked \(result.totalUniqueWords) unique words to ranked-words.json"
            }
        } catch {
            appState.rankedExportStatus = "Ranked export failed: \(error.localizedDescription)"
        }
    }

    func practiceNowRequested() {
        let extractionService = WordExtractionService(fileLocations: fileLocations)
        let ranker = WordRanker()
        let builder = PracticePromptBuilder()

        do {
            let extraction = try extractionService.extractInMemory()
            let ranked = ranker.rank(extraction.words)
            let prompt = builder.build(from: ranked, wordCount: 50)

            guard !prompt.words.isEmpty else {
                appState.practiceStatus = "No words available for practice"
                return
            }

            appState.practiceStatus = nil
            onOpenPractice(prompt)
        } catch {
            appState.practiceStatus = "Practice generation failed: \(error.localizedDescription)"
        }
    }

    func openSystemSettingsRequested() {
        permissionManager.openSystemSettings()
    }

    private func recoverStateIfNeeded(for status: AppState.PermissionStatus) {
        guard status == .granted else { return }

        if case .blocked = appState.loggingStatus {
            appState.loggingStatus = .disabled
        }
        appState.clearRuntimeErrorIfRecoverable()
    }

    private func handle(_ event: NormalizedKeyEvent) {
        let transcriptEvent = TranscriptEvent(
            seq: nextSeq,
            ts: TimestampFormatter.string(from: Date()),
            type: event.type,
            keyCode: event.keyCode,
            characters: event.characters,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            modifiers: event.modifiers,
            isRepeat: event.isRepeat,
            keyboardLayout: event.keyboardLayout
        )

        do {
            try transcriptWriter.append(transcriptEvent)
            nextSeq += 1
        } catch {
            keyboardMonitor.stop()
            appState.loggingStatus = .error(message: "Unable to write transcript: \(error.localizedDescription)")
        }
    }
}
