import XCTest
@testable import TypingLens

final class PracticeViewModelTests: XCTestCase {
    func testInitialStateReflectsPrompt() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["alpha", "beta"]))

        XCTAssertEqual(viewModel.promptWords, ["alpha", "beta"])
        XCTAssertTrue(viewModel.submittedWords.isEmpty)
        XCTAssertEqual(viewModel.currentInput, "")
        XCTAssertNil(viewModel.startedAt)
        XCTAssertNil(viewModel.finishedAt)
        XCTAssertEqual(viewModel.currentWordIndex, 0)
        XCTAssertFalse(viewModel.isFinished)
        XCTAssertEqual(viewModel.progressLabel, "0 / 2")
        XCTAssertEqual(viewModel.wpm, 0)
        XCTAssertEqual(viewModel.accuracy, 100)
    }

    func testSubmitStartsTimerOnFirstMeaningfulWord() {
        let clock = FakeClock(times: [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 20)
        ])
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["hello"]),
            now: clock.next,
            onNewPrompt: {}
        )

        viewModel.currentInput = "hello"
        viewModel.submitCurrentWord()

        XCTAssertEqual(viewModel.startedAt, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(viewModel.currentWordIndex, 1)
    }

    func testCurrentWordIndexAndProgressUpdateAfterSubmissions() {
        let clock = FakeClock(times: [
            Date(timeIntervalSince1970: 1),
            Date(timeIntervalSince1970: 2),
            Date(timeIntervalSince1970: 3)
        ])
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["one", "two", "three"]),
            now: clock.next
        )

        viewModel.currentInput = "one"
        viewModel.submitCurrentWord()
        XCTAssertEqual(viewModel.currentWordIndex, 1)
        XCTAssertEqual(viewModel.progressLabel, "1 / 3")

        viewModel.currentInput = "two"
        viewModel.submitCurrentWord()
        XCTAssertEqual(viewModel.currentWordIndex, 2)
        XCTAssertEqual(viewModel.progressLabel, "2 / 3")

        viewModel.currentInput = "three"
        viewModel.submitCurrentWord()
        XCTAssertEqual(viewModel.currentWordIndex, 3)
        XCTAssertEqual(viewModel.progressLabel, "3 / 3")
        XCTAssertTrue(viewModel.isFinished)
    }

    func testMistakesReduceAccuracy() {
        let clock = FakeClock(times: [
            Date(timeIntervalSince1970: 1),
            Date(timeIntervalSince1970: 2),
            Date(timeIntervalSince1970: 3)
        ])
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["focus", "type"]),
            now: clock.next
        )

        viewModel.currentInput = "focs"
        viewModel.submitCurrentWord()

        viewModel.currentInput = "types"
        viewModel.submitCurrentWord()

        // focus: 3/5 correct, type vs types: 4/5 correct => 7/10 => 70%
        XCTAssertEqual(viewModel.currentWordIndex, 2)
        XCTAssertEqual(viewModel.accuracy, 70, accuracy: 0.01)
    }

    func testCompletionMarksFinishedAtAndLocksState() {
        let clock = FakeClock(times: [
            Date(timeIntervalSince1970: 1),
            Date(timeIntervalSince1970: 2)
        ])
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["hi", "yo"]),
            now: clock.next
        )

        viewModel.currentInput = "hi"
        viewModel.submitCurrentWord()
        viewModel.currentInput = "yo"
        viewModel.submitCurrentWord()

        XCTAssertTrue(viewModel.isFinished)
        XCTAssertEqual(viewModel.currentWordIndex, 2)
        XCTAssertEqual(viewModel.finishedAt, Date(timeIntervalSince1970: 2))

        viewModel.currentInput = "extra"
        viewModel.submitCurrentWord()

        XCTAssertEqual(viewModel.currentWordIndex, 2)
        XCTAssertEqual(viewModel.finishedAt, Date(timeIntervalSince1970: 2))
    }

    func testRestartClearsProgressKeepsPromptWords() {
        let clock = FakeClock(times: [
            Date(timeIntervalSince1970: 1),
            Date(timeIntervalSince1970: 2),
            Date(timeIntervalSince1970: 3)
        ])
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["alpha", "beta"]),
            now: clock.next
        )

        viewModel.currentInput = "alpha"
        viewModel.submitCurrentWord()
        viewModel.restart()

        XCTAssertEqual(viewModel.promptWords, ["alpha", "beta"])
        XCTAssertTrue(viewModel.submittedWords.isEmpty)
        XCTAssertNil(viewModel.startedAt)
        XCTAssertNil(viewModel.finishedAt)
        XCTAssertEqual(viewModel.currentInput, "")
        XCTAssertEqual(viewModel.currentWordIndex, 0)
        XCTAssertFalse(viewModel.isFinished)
    }

    func testRequestNewPromptInvokesCallback() {
        var requested = false
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["alpha"]),
            onNewPrompt: { requested = true }
        )

        viewModel.requestNewPrompt()

        XCTAssertTrue(requested)
    }

    func testWpmUsesSessionDurationAndIsStableAfterCompletion() {
        let clock = FakeClock(times: [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 70),
            Date(timeIntervalSince1970: 130)
        ])
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["hello", "world"]),
            now: clock.next
        )

        viewModel.currentInput = "alpha"
        viewModel.submitCurrentWord()
        viewModel.currentInput = "beta"
        viewModel.submitCurrentWord()

        let finalWpm = viewModel.wpm

        viewModel.currentInput = "ignored"
        viewModel.submitCurrentWord()

        XCTAssertEqual(finalWpm, 2, accuracy: 0.001)
        XCTAssertEqual(viewModel.wpm, 2, accuracy: 0.001)
    }

    func testHandleTypedCharacterPreservesLiveTypedCharacters() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["hello", "world"]))

        viewModel.handleTypedCharacter("h")
        viewModel.handleTypedCharacter("e")
        viewModel.handleTypedCharacter("l")

        XCTAssertEqual(viewModel.currentInput, "hel")
        XCTAssertEqual(viewModel.currentWordIndex, 0)
        XCTAssertTrue(viewModel.submittedWords.isEmpty)
    }

    func testWhitespaceCharacterSubmitsCurrentWord() {
        let clock = FakeClock(times: [
            Date(timeIntervalSince1970: 10)
        ])
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["hello", "world"]),
            now: clock.next
        )

        for character in "hello" {
            viewModel.handleTypedCharacter(character)
        }
        viewModel.handleTypedCharacter(" ")

        XCTAssertEqual(viewModel.currentWordIndex, 1)
        XCTAssertEqual(viewModel.submittedWords, ["hello"])
        XCTAssertEqual(viewModel.currentInput, "")
        XCTAssertEqual(viewModel.startedAt, Date(timeIntervalSince1970: 10))
    }

    func testBackspaceRemovesLastTypedCharacterWithoutSubmitting() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["hello", "world"]))

        viewModel.handleTypedCharacter("h")
        viewModel.handleTypedCharacter("e")
        viewModel.handleTypedCharacter("l")
        viewModel.handleBackspace()

        XCTAssertEqual(viewModel.currentInput, "he")
        XCTAssertEqual(viewModel.currentWordIndex, 0)
        XCTAssertTrue(viewModel.submittedWords.isEmpty)
    }

    func testSecondWordStartsFreshAfterFirstWordSubmission() {
        let clock = FakeClock(times: [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 20)
        ])
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["hello", "world"]),
            now: clock.next
        )

        for character in "jjjjdj" {
            viewModel.handleTypedCharacter(character)
        }
        viewModel.handleTypedCharacter(" ")
        viewModel.handleTypedCharacter("j")

        XCTAssertEqual(viewModel.currentWordIndex, 1)
        XCTAssertEqual(viewModel.submittedWords, ["jjjjdj"])
        XCTAssertEqual(viewModel.currentInput, "j")
    }
}

private final class FakeClock {
    private var times: [Date]
    private var index: Int = 0

    init(times: [Date]) {
        self.times = times
    }

    func next() -> Date {
        let value = times[min(index, times.count - 1)]
        index += 1
        return value
    }
}
