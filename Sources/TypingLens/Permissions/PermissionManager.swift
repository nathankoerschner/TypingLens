import AppKit
import ApplicationServices
import Foundation

protocol PermissionManaging {
    func currentStatus() -> AppState.PermissionStatus
    func refreshStatus() -> AppState.PermissionStatus
    func openSystemSettings()
}

final class PermissionManager: PermissionManaging {
    private let trustChecker: () -> Bool
    private let settingsOpener: (URL) -> Void

    init(
        trustChecker: @escaping () -> Bool = { AXIsProcessTrusted() },
        settingsOpener: @escaping (URL) -> Void = { url in
            NSWorkspace.shared.open(url)
        }
    ) {
        self.trustChecker = trustChecker
        self.settingsOpener = settingsOpener
    }

    func currentStatus() -> AppState.PermissionStatus {
        trustChecker() ? .granted : .notGranted
    }

    func refreshStatus() -> AppState.PermissionStatus {
        currentStatus()
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        settingsOpener(url)
    }
}
