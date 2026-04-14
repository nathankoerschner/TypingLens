import Foundation

struct SettingsViewState: Equatable {
    let permissionStatus: String
    let loggingStatus: String
    let launchAtLoginEnabled: Bool
    let transcriptPath: String
    let currentErrorMessage: String?
    let extractionStatus: String?
    let rankedExportStatus: String?
}

struct SettingsViewModel {
    let onRefreshPermissionStatus: () -> Void
    let onOpenSystemSettings: () -> Void
    let onRevealTranscript: () -> Void
    let onClearTranscript: () -> Void
    let onToggleLaunchAtLogin: (Bool) -> Void
    let onExtractWords: () -> Void
    let onExportRankedWords: () -> Void

    func state(for appState: AppState) -> SettingsViewState {
        SettingsViewState(
            permissionStatus: appState.permissionStatusLabel,
            loggingStatus: loggingStatusLabel(for: appState),
            launchAtLoginEnabled: appState.launchAtLoginEnabled,
            transcriptPath: appState.transcriptPath,
            currentErrorMessage: appState.currentErrorMessage,
            extractionStatus: appState.extractionStatus,
            rankedExportStatus: appState.rankedExportStatus
        )
    }

    func toggleLaunchAtLogin(_ isEnabled: Bool) {
        onToggleLaunchAtLogin(isEnabled)
    }

    func refreshPermissionStatus() {
        onRefreshPermissionStatus()
    }

    func openSystemSettings() {
        onOpenSystemSettings()
    }

    func revealTranscript() {
        onRevealTranscript()
    }

    func clearTranscript() {
        onClearTranscript()
    }

    func extractWords() {
        onExtractWords()
    }

    func exportRankedWords() {
        onExportRankedWords()
    }

    private func loggingStatusLabel(for appState: AppState) -> String {
        switch appState.loggingStatus {
        case .disabled:
            return "Disabled"
        case .enabling:
            return "Enabling"
        case .enabled:
            return "Enabled"
        case let .blocked(reason):
            return "Blocked – \(reason)"
        case let .error(message):
            return "Error – \(message)"
        }
    }
}
