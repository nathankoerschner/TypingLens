import Foundation
import XCTest
@testable import TypingLens

final class TranscriptEncodingTests: XCTestCase {
    func testKeyDownEventEncodesAsExpectedCompactJSON() throws {
        let event = TranscriptEvent(
            seq: 41,
            ts: "2026-04-14T12:01:03.510123Z",
            type: .keyDown,
            keyCode: 0,
            characters: "A",
            charactersIgnoringModifiers: "a",
            modifiers: ["shift"],
            isRepeat: false,
            keyboardLayout: nil
        )

        let data = try JSONEncoder.transcriptEncoder().encode(event)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(json.contains(" "))
        let decoded = try JSONDecoder().decode(TranscriptEvent.self, from: data)
        XCTAssertEqual(decoded, event)
    }

    func testKeyUpEventEncodesWithExpectedShape() throws {
        let event = TranscriptEvent(
            seq: 42,
            ts: "2026-04-14T12:01:04.000000Z",
            type: .keyUp,
            keyCode: 36,
            characters: nil,
            charactersIgnoringModifiers: nil,
            modifiers: [],
            isRepeat: true,
            keyboardLayout: nil
        )

        let data = try JSONEncoder.transcriptEncoder().encode(event)
        let decoded = try JSONDecoder().decode(TranscriptEvent.self, from: data)

        XCTAssertEqual(decoded.seq, 42)
        XCTAssertEqual(decoded.type, .keyUp)
        XCTAssertNil(decoded.characters)
        XCTAssertNil(decoded.charactersIgnoringModifiers)
        XCTAssertTrue(decoded.modifiers.isEmpty)
        XCTAssertTrue(decoded.isRepeat)
    }
}
