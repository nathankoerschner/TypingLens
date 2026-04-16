import AppKit
import XCTest
@testable import TypingLens

final class ApplicationBootstrapTests: XCTestCase {
    func testConfigureMenuBarActivationPolicySetsAccessoryPolicyOnSharedApplication() {
        let previousPolicy = NSApplication.shared.activationPolicy()
        defer {
            _ = NSApplication.shared.setActivationPolicy(previousPolicy)
        }

        ApplicationBootstrap.configureMenuBarActivationPolicy()

        XCTAssertEqual(NSApplication.shared.activationPolicy(), .accessory)
    }

    func testConfigureWindowActivationPolicySetsRegularPolicyOnSharedApplication() {
        let previousPolicy = NSApplication.shared.activationPolicy()
        defer {
            _ = NSApplication.shared.setActivationPolicy(previousPolicy)
        }

        ApplicationBootstrap.configureWindowActivationPolicy()

        XCTAssertEqual(NSApplication.shared.activationPolicy(), .regular)
    }
}
