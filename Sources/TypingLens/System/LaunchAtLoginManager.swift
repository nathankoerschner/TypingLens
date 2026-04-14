import Foundation

protocol LaunchAtLoginManaging {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}

enum LaunchAtLoginManagerError: LocalizedError, Equatable {
    case failedToPersist(String)

    var errorDescription: String? {
        switch self {
        case let .failedToPersist(message):
            return "Unable to update launch-at-login preference: \(message)"
        }
    }
}

final class LaunchAtLoginManager: LaunchAtLoginManaging {
    private let preferencesStore: PreferencesStoring

    init(preferencesStore: PreferencesStoring = PreferencesStore()) {
        self.preferencesStore = preferencesStore
    }

    func isEnabled() -> Bool {
        preferencesStore.launchAtLoginEnabled()
    }

    func setEnabled(_ enabled: Bool) throws {
        do {
            try preferencesStore.setLaunchAtLoginEnabled(enabled)
        } catch {
            throw LaunchAtLoginManagerError.failedToPersist(error.localizedDescription)
        }
    }
}
