import Foundation
import XCTest
@testable import TypingLens

final class PermissionManagerTests: XCTestCase {
    func testCurrentStatusMapsTrustedProcessToGranted() {
        let manager = PermissionManager(trustChecker: { true }, settingsOpener: { _ in })

        XCTAssertEqual(manager.currentStatus(), .granted)
        XCTAssertEqual(manager.refreshStatus(), .granted)
    }

    func testCurrentStatusMapsUntrustedProcessToNotGranted() {
        let manager = PermissionManager(trustChecker: { false }, settingsOpener: { _ in })

        XCTAssertEqual(manager.currentStatus(), .notGranted)
    }

    func testOpenSystemSettingsUsesAccessibilityPrivacyURL() {
        var openedURL: URL?
        let manager = PermissionManager(
            trustChecker: { false },
            settingsOpener: { openedURL = $0 }
        )

        manager.openSystemSettings()

        XCTAssertEqual(
            openedURL?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }
}
