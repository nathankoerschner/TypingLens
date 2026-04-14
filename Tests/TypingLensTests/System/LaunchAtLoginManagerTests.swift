import Foundation
import XCTest
@testable import TypingLens

final class LaunchAtLoginManagerTests: XCTestCase {
    func testLaunchAtLoginDefaultsArePersistedAndRestored() throws {
        let store = InMemoryPreferencesStore()
        let manager = LaunchAtLoginManager(preferencesStore: store)

        XCTAssertFalse(manager.isEnabled())

        try manager.setEnabled(true)
        XCTAssertTrue(manager.isEnabled())

        try manager.setEnabled(false)
        XCTAssertFalse(manager.isEnabled())
    }

    func testSetEnabledMapsPersistenceErrorsToManagerError() {
        let failingStore = FailingPreferencesStore()
        let manager = LaunchAtLoginManager(preferencesStore: failingStore)

        XCTAssertThrowsError(try manager.setEnabled(true)) { error in
            XCTAssertEqual(
                error as? LaunchAtLoginManagerError,
                .failedToPersist("Failed to write preference")
            )
        }
    }
}

private final class InMemoryPreferencesStore: PreferencesStoring {
    private(set) var value: Bool = false

    func launchAtLoginEnabled() -> Bool {
        value
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) throws {
        value = enabled
    }
}

private final class FailingPreferencesStore: PreferencesStoring {
    func launchAtLoginEnabled() -> Bool {
        false
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) throws {
        throw FailingPreferencesStoreError.persistFailed
    }
}

private enum FailingPreferencesStoreError: LocalizedError, Equatable {
    case persistFailed

    var errorDescription: String? {
        switch self {
        case .persistFailed:
            return "Failed to write preference"
        }
    }
}
