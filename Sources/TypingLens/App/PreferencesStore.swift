import Foundation

protocol PreferencesStoring {
    func launchAtLoginEnabled() -> Bool
    func setLaunchAtLoginEnabled(_ enabled: Bool) throws
}

final class PreferencesStore: PreferencesStoring {
    private let userDefaults: UserDefaults
    private let launchAtLoginKey = "launchAtLoginEnabled"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func launchAtLoginEnabled() -> Bool {
        userDefaults.bool(forKey: launchAtLoginKey)
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) throws {
        userDefaults.set(enabled, forKey: launchAtLoginKey)
    }
}
