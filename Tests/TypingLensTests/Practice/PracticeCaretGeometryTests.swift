import CoreGraphics
import XCTest
@testable import TypingLens

final class PracticeCaretGeometryTests: XCTestCase {
    func testResolveReturnsWordLeadingEdgeAtStartOfWord() {
        let target = resolvePracticeCaretTarget(
            caretState: PracticeCaretState(wordIndex: 1, letterIndex: 0),
            wordFrames: [1: CGRect(x: 120, y: 54, width: 80, height: 42)],
            letterFrames: [:]
        )

        XCTAssertEqual(target, PracticeCaretTarget(x: 120, y: 54, height: 42))
    }

    func testResolveReturnsMeasuredLetterOriginWithinWord() {
        let target = resolvePracticeCaretTarget(
            caretState: PracticeCaretState(wordIndex: 0, letterIndex: 2),
            wordFrames: [0: CGRect(x: 0, y: 0, width: 100, height: 40)],
            letterFrames: [
                PracticeLetterFrameID(wordIndex: 0, letterIndex: 2): CGRect(x: 32, y: 0, width: 16, height: 40)
            ]
        )

        XCTAssertEqual(target, PracticeCaretTarget(x: 32, y: 0, height: 40))
    }

    func testResolveUsesTrailingEdgeForEndOfWordAndOvertyping() {
        let target = resolvePracticeCaretTarget(
            caretState: PracticeCaretState(wordIndex: 0, letterIndex: 5),
            wordFrames: [0: CGRect(x: 0, y: 0, width: 100, height: 40)],
            letterFrames: [
                PracticeLetterFrameID(wordIndex: 0, letterIndex: 4): CGRect(x: 64, y: 0, width: 16, height: 40)
            ]
        )

        XCTAssertEqual(target, PracticeCaretTarget(x: 80, y: 0, height: 40))
    }

    func testResolvePreservesWrappedRowYPosition() {
        let target = resolvePracticeCaretTarget(
            caretState: PracticeCaretState(wordIndex: 3, letterIndex: 1),
            wordFrames: [3: CGRect(x: 18, y: 58, width: 90, height: 38)],
            letterFrames: [
                PracticeLetterFrameID(wordIndex: 3, letterIndex: 1): CGRect(x: 36, y: 58, width: 18, height: 38)
            ]
        )

        XCTAssertEqual(target?.y, 58)
        XCTAssertEqual(target?.height, 38)
    }

    func testResolveReturnsNilWhenCaretStateIsMissingOrFinished() {
        XCTAssertNil(
            resolvePracticeCaretTarget(
                caretState: nil,
                wordFrames: [0: CGRect(x: 0, y: 0, width: 100, height: 24)],
                letterFrames: [:]
            )
        )
    }
}
