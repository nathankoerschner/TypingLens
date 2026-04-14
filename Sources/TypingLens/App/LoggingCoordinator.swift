import Foundation

final class LoggingCoordinator {
    private let appState: AppState
    private let permissionManager: PermissionManaging
    private let keyboardMonitor: KeyboardMonitoring
    private let transcriptWriter: TranscriptWriting
    private var nextSeq: Int64 = 1

    init(
        appState: AppState,
        permissionManager: PermissionManaging,
        keyboardMonitor: KeyboardMonitoring,
        transcriptWriter: TranscriptWriting
    ) throws {
        self.appState = appState
        self.permissionManager = permissionManager
        self.keyboardMonitor = keyboardMonitor
        self.transcriptWriter = transcriptWriter
        self.nextSeq = try transcriptWriter.initializeNextSequence()
    }

    init(
        appState: AppState,
        permissionManager: PermissionManaging,
        keyboardMonitor: KeyboardMonitoring,
        transcriptWriter: TranscriptWriting,
        initialSequence: Int64
    ) {
        self.appState = appState
        self.permissionManager = permissionManager
        self.keyboardMonitor = keyboardMonitor
        self.transcriptWriter = transcriptWriter
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
