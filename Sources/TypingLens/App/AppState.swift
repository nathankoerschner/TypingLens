import Foundation
import SwiftUI

final class AppState: ObservableObject {
    enum LoggingStatus: Equatable {
        case disabled
        case enabling
        case enabled
        case blocked(reason: String)
        case error(message: String)
    }

    enum PermissionStatus: Equatable {
        case unknown
        case granted
        case notGranted
        case needsRetry
    }

    @Published var permissionStatus: PermissionStatus
    @Published var loggingStatus: LoggingStatus
    @Published var transcriptPath: String
    @Published var launchAtLoginEnabled: Bool

    init(
        transcriptPath: String,
        permissionStatus: PermissionStatus,
        loggingStatus: LoggingStatus,
        launchAtLoginEnabled: Bool
    ) {
        self.transcriptPath = transcriptPath
        self.permissionStatus = permissionStatus
        self.loggingStatus = loggingStatus
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }

    var isLoggingEnabled: Bool {
        if case .enabled = loggingStatus { return true }
        return false
    }

    var currentErrorMessage: String? {
        if case let .error(message) = loggingStatus {
            return message
        }
        return nil
    }

    func applyPermissionStatus(_ status: PermissionStatus) {
        permissionStatus = status

        if status != .granted, isLoggingEnabled {
            loggingStatus = .blocked(reason: "Permission required")
        }
    }

    func clearRuntimeErrorIfRecoverable() {
        if case .error = loggingStatus {
            loggingStatus = .disabled
        }
    }

    var permissionStatusLabel: String {
        switch permissionStatus {
        case .unknown:
            return "Unknown"
        case .granted:
            return "Granted"
        case .notGranted:
            return "Not Granted"
        case .needsRetry:
            return "Needs Retry"
        }
    }
}
