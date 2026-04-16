import AppKit
import XCTest
@testable import TypingLens

final class WindowActivationControllerTests: XCTestCase {
    func testShowingAWindowPromotesAppToRegularActivationPolicy() {
        let application = StubActivationPolicySetter()
        var promoteCount = 0
        let controller = WindowActivationController(
            application: application,
            onPromoteToRegularApp: { promoteCount += 1 }
        )

        controller.setWindowVisible(true, identifier: "practice")

        XCTAssertEqual(application.activationPolicies, [.regular])
        XCTAssertEqual(promoteCount, 1)
    }

    func testHidingLastWindowReturnsAppToAccessoryActivationPolicy() {
        let application = StubActivationPolicySetter()
        var promoteCount = 0
        let controller = WindowActivationController(
            application: application,
            onPromoteToRegularApp: { promoteCount += 1 }
        )

        controller.setWindowVisible(true, identifier: "practice")
        controller.setWindowVisible(false, identifier: "practice")

        XCTAssertEqual(application.activationPolicies, [.regular, .accessory])
        XCTAssertEqual(promoteCount, 1)
    }

    func testHidingOneWindowKeepsRegularPolicyWhileAnotherWindowRemainsVisible() {
        let application = StubActivationPolicySetter()
        var promoteCount = 0
        let controller = WindowActivationController(
            application: application,
            onPromoteToRegularApp: { promoteCount += 1 }
        )

        controller.setWindowVisible(true, identifier: "practice")
        controller.setWindowVisible(true, identifier: "analytics")
        controller.setWindowVisible(false, identifier: "practice")

        XCTAssertEqual(application.activationPolicies, [.regular, .regular, .regular])
        XCTAssertEqual(promoteCount, 3)
    }
}

private final class StubActivationPolicySetter: ActivationPolicySetting {
    private(set) var activationPolicies: [NSApplication.ActivationPolicy] = []

    @discardableResult
    func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool {
        activationPolicies.append(activationPolicy)
        return true
    }
}
