import AppKit
import XCTest
@testable import TypingLens

final class MenuBarControllerTests: XCTestCase {
    func testMenuBuilderTargetsAllActionsToProvidedTargetAndRespectsStateEnabledFlags() throws {
        let target = StubMenuActionTarget()
        let menu = MenuBarController.makeMenu(
            target: target,
            state: .init(
                statusTitle: "Status: Disabled",
                enableLoggingEnabled: true,
                disableLoggingEnabled: false
            )
        )

        try assertActionItem(
            in: menu,
            title: "Enable Logging",
            expectedAction: "enableLogging",
            target: target,
            isEnabled: true
        )
        try assertActionItem(
            in: menu,
            title: "Disable Logging",
            expectedAction: "disableLogging",
            target: target,
            isEnabled: false
        )
        try assertActionItem(
            in: menu,
            title: "Open Settings…",
            expectedAction: "openSettings",
            target: target,
            isEnabled: true
        )
        try assertActionItem(
            in: menu,
            title: "Practice Now",
            expectedAction: "practiceNow",
            target: target,
            isEnabled: true,
            keyEquivalent: "",
            modifiers: []
        )
        try assertActionItem(
            in: menu,
            title: "Reveal Transcript in Finder",
            expectedAction: "revealTranscript",
            target: target,
            isEnabled: true
        )
        try assertActionItem(
            in: menu,
            title: "Clear Transcript",
            expectedAction: "clearTranscript",
            target: target,
            isEnabled: true
        )
        try assertActionItem(
            in: menu,
            title: "Quit",
            expectedAction: "quit",
            target: target,
            isEnabled: true
        )
    }

    private func assertActionItem(
        in menu: NSMenu,
        title: String,
        expectedAction: String,
        target: AnyObject,
        isEnabled: Bool,
        keyEquivalent: String? = nil,
        modifiers: NSEvent.ModifierFlags? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let item = try XCTUnwrap(menu.item(withTitle: title), file: file, line: line)
        XCTAssertEqual(item.action.map(NSStringFromSelector), expectedAction, file: file, line: line)
        XCTAssertTrue(item.target === target, file: file, line: line)
        XCTAssertEqual(item.isEnabled, isEnabled, file: file, line: line)
        if let keyEquivalent {
            XCTAssertEqual(item.keyEquivalent, keyEquivalent, file: file, line: line)
        }
        if let modifiers {
            XCTAssertEqual(item.keyEquivalentModifierMask, modifiers, file: file, line: line)
        }
    }
}

private final class StubMenuActionTarget: NSObject {
    @objc func enableLogging() {}
    @objc func disableLogging() {}
    @objc func openSettings() {}
    @objc func practiceNow() {}
    @objc func revealTranscript() {}
    @objc func clearTranscript() {}
    @objc func quit() {}
}
