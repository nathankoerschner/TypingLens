import AppKit
import XCTest
@testable import TypingLens

final class PracticeKeyCaptureViewTests: XCTestCase {
    func testInsertDispatchesInsertCallbackForPrintableCharacter() {
        let view = KeyCaptureNSView()
        var insertedCharacters: [Character] = []
        view.onInsert = { insertedCharacters.append($0) }

        view.keyDown(with: makeEvent(
            keyCode: 0,
            characters: "a",
            charactersIgnoringModifiers: "a"
        ))

        XCTAssertEqual(insertedCharacters, ["a"])
    }

    func testSubmitDispatchesSubmitCallbackForWhitespace() {
        let view = KeyCaptureNSView()
        var didSubmit = false
        view.onSubmit = { didSubmit = true }

        view.keyDown(with: makeEvent(
            keyCode: 49,
            characters: " ",
            charactersIgnoringModifiers: " "
        ))

        XCTAssertTrue(didSubmit)
    }

    func testSubmitDispatchesSubmitCallbackForNewline() {
        let view = KeyCaptureNSView()
        var didSubmit = false
        view.onSubmit = { didSubmit = true }

        view.keyDown(with: makeEvent(
            keyCode: 36,
            characters: "\n",
            charactersIgnoringModifiers: "\n"
        ))

        XCTAssertTrue(didSubmit)
    }

    func testBackspaceDispatchesDeleteBackwardCallback() {
        let view = KeyCaptureNSView()
        var didDelete = false
        view.onDeleteBackward = { didDelete = true }

        view.keyDown(with: makeEvent(
            keyCode: 51,
            characters: "",
            charactersIgnoringModifiers: ""
        ))

        XCTAssertTrue(didDelete)
    }

    func testDisallowedModifierBypassesInsertRouting() {
        let view = KeyCaptureNSView()
        var insertedCharacters: [Character] = []
        view.onInsert = { insertedCharacters.append($0) }

        view.keyDown(with: makeEvent(
            keyCode: 0,
            characters: "a",
            charactersIgnoringModifiers: "a",
            modifierFlags: [.command]
        ))

        XCTAssertEqual(insertedCharacters.count, 0)
    }

    func testDisallowedModifierDoesNotInvokeDeleteBackward() {
        let view = KeyCaptureNSView()
        var didDelete = false
        view.onDeleteBackward = { didDelete = true }

        view.keyDown(with: makeEvent(
            keyCode: 51,
            characters: "",
            charactersIgnoringModifiers: "",
            modifierFlags: [.command]
        ))

        XCTAssertFalse(didDelete)
    }

    func testDisabledStateSuppressesCallbacks() {
        let view = KeyCaptureNSView()
        var didInsert = false
        var didSubmit = false
        var didDelete = false

        view.isDisabled = true
        view.onInsert = { _ in didInsert = true }
        view.onSubmit = { didSubmit = true }
        view.onDeleteBackward = { didDelete = true }

        view.keyDown(with: makeEvent(
            keyCode: 0,
            characters: "a",
            charactersIgnoringModifiers: "a"
        ))
        XCTAssertFalse(didInsert)

        view.keyDown(with: makeEvent(
            keyCode: 49,
            characters: " ",
            charactersIgnoringModifiers: " "
        ))
        XCTAssertFalse(didSubmit)

        view.keyDown(with: makeEvent(
            keyCode: 51,
            characters: "",
            charactersIgnoringModifiers: ""
        ))
        XCTAssertFalse(didDelete)
    }
}

private extension PracticeKeyCaptureViewTests {
    func makeEvent(
        keyCode: UInt16,
        characters: String,
        charactersIgnoringModifiers: String,
        modifierFlags: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: keyCode
        )

                return event!
    }
}
