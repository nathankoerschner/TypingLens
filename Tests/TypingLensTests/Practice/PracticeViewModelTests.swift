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

        viewModel.type("hello")
        viewModel.handleSubmit()

        XCTAssertEqual(viewModel.startedAt, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(viewModel.currentWordIndex, 1)
    }

    func testCurrentWordIndexAndProgressUpdateAfterSubmissions() {
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["one", "two", "three"])
        )

        viewModel.type("one")
        viewModel.handleSubmit()
        XCTAssertEqual(viewModel.currentWordIndex, 1)
        XCTAssertEqual(viewModel.progressLabel, "1 / 3")

        viewModel.type("two")
        viewModel.handleSubmit()
        XCTAssertEqual(viewModel.currentWordIndex, 2)
        XCTAssertEqual(viewModel.progressLabel, "2 / 3")

        viewModel.type("three")
        viewModel.handleSubmit()
        XCTAssertEqual(viewModel.currentWordIndex, 3)
        XCTAssertEqual(viewModel.progressLabel, "3 / 3")
        XCTAssertTrue(viewModel.isFinished)
    }

    func testMistakesReduceAccuracy() {
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["focus", "type"])
        )

        viewModel.type("focs")
        viewModel.handleSubmit()

        viewModel.type("types")
        viewModel.handleSubmit()

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

        viewModel.type("hi")
        viewModel.handleSubmit()
        viewModel.type("yo")
        viewModel.handleSubmit()

        XCTAssertTrue(viewModel.isFinished)
        XCTAssertEqual(viewModel.currentWordIndex, 2)
        XCTAssertEqual(viewModel.finishedAt, Date(timeIntervalSince1970: 2))

        viewModel.type("extra")
        viewModel.handleSubmit()

        XCTAssertEqual(viewModel.currentWordIndex, 2)
        XCTAssertEqual(viewModel.finishedAt, Date(timeIntervalSince1970: 2))
    }

    func testRestartClearsProgressKeepsPromptWords() {
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["alpha", "beta"])
        )

        viewModel.type("alpha")
        viewModel.handleSubmit()
        viewModel.restart()

        XCTAssertEqual(viewModel.promptWords, ["alpha", "beta"])
        XCTAssertTrue(viewModel.submittedWords.isEmpty)
        XCTAssertNil(viewModel.startedAt)
        XCTAssertNil(viewModel.finishedAt)
        XCTAssertEqual(viewModel.currentInput, "")
        XCTAssertEqual(viewModel.currentWordIndex, 0)
        XCTAssertFalse(viewModel.isFinished)
        XCTAssertFalse(viewModel.canRestorePreviousWord)
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

        viewModel.type("alpha")
        viewModel.handleSubmit()
        viewModel.type("beta")
        viewModel.handleSubmit()

        let finalWpm = viewModel.wpm

        viewModel.type("ignored")
        viewModel.handleSubmit()

        XCTAssertEqual(finalWpm, 2, accuracy: 0.001)
        XCTAssertEqual(viewModel.wpm, 2, accuracy: 0.001)
    }

    func testHandleInsertPreservesLiveTypedCharacters() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["hello", "world"]))

        viewModel.handleInsert("h")
        viewModel.handleInsert("e")
        viewModel.handleInsert("l")

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

        viewModel.type("hello")
        viewModel.handleInsert(" ")

        XCTAssertEqual(viewModel.currentWordIndex, 1)
        XCTAssertEqual(viewModel.submittedWords, ["hello"])
        XCTAssertEqual(viewModel.currentInput, "")
        XCTAssertEqual(viewModel.startedAt, Date(timeIntervalSince1970: 10))
    }

    func testBackspaceRemovesLastTypedCharacterWithoutSubmitting() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["hello", "world"]))

        viewModel.type("hel")
        viewModel.handleDeleteBackward()

        XCTAssertEqual(viewModel.currentInput, "he")
        XCTAssertEqual(viewModel.currentWordIndex, 0)
        XCTAssertTrue(viewModel.submittedWords.isEmpty)
    }

    func testSecondWordStartsFreshAfterFirstWordSubmission() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["hello", "world"]))

        viewModel.type("jjjjdj")
        viewModel.handleSubmit()
        viewModel.type("j")

        XCTAssertEqual(viewModel.currentWordIndex, 1)
        XCTAssertEqual(viewModel.submittedWords, ["jjjjdj"])
        XCTAssertEqual(viewModel.currentInput, "j")
    }

    func testDeleteBackwardRestoresPreviousCommittedWordWhenCurrentWordIsEmpty() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["alpha", "beta"]))

        viewModel.type("alpha")
        viewModel.handleSubmit()

        XCTAssertEqual(viewModel.currentWordIndex, 1)
        XCTAssertEqual(viewModel.currentInput, "")
        XCTAssertEqual(viewModel.submittedWords, ["alpha"])

        viewModel.handleDeleteBackward()

        XCTAssertEqual(viewModel.currentWordIndex, 0)
        XCTAssertEqual(viewModel.currentInput, "alpha")
        XCTAssertTrue(viewModel.submittedWords.isEmpty)
    }

    func testDeleteBackwardCanRestoreAcrossMultipleCommittedWords() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["alpha", "beta", "gamma"]))

        viewModel.type("alpha")
        viewModel.handleSubmit()
        viewModel.type("beta")
        viewModel.handleSubmit()
        viewModel.type("gamma")
        viewModel.handleSubmit()

        XCTAssertEqual(viewModel.currentWordIndex, 3)
        XCTAssertTrue(viewModel.isFinished)
        XCTAssertEqual(viewModel.currentInput, "")
        XCTAssertEqual(viewModel.submittedWords, ["alpha", "beta", "gamma"])

        viewModel.handleDeleteBackward()

        XCTAssertEqual(viewModel.currentWordIndex, 2)
        XCTAssertEqual(viewModel.currentInput, "gamma")
        XCTAssertNil(viewModel.finishedAt)
        XCTAssertEqual(viewModel.submittedWords, ["alpha", "beta"])

        while !viewModel.currentInput.isEmpty {
            viewModel.handleDeleteBackward()
        }

        viewModel.handleDeleteBackward()

        XCTAssertEqual(viewModel.currentWordIndex, 1)
        XCTAssertEqual(viewModel.currentInput, "beta")
        XCTAssertEqual(viewModel.submittedWords, ["alpha"])
    }

    func testRewindAfterCompletionClearsFinishedAt() {
        let clock = FakeClock(times: [
            Date(timeIntervalSince1970: 1),
            Date(timeIntervalSince1970: 2),
            Date(timeIntervalSince1970: 3),
            Date(timeIntervalSince1970: 4)
        ])
        let viewModel = PracticeViewModel(
            prompt: PracticePrompt(words: ["alpha", "beta"]),
            now: clock.next
        )

        viewModel.type("alpha")
        viewModel.handleSubmit()
        viewModel.type("beta")
        viewModel.handleSubmit()

        XCTAssertEqual(viewModel.finishedAt, Date(timeIntervalSince1970: 2))

        viewModel.handleDeleteBackward()

        XCTAssertNil(viewModel.finishedAt)
        XCTAssertEqual(viewModel.currentWordIndex, 1)
        XCTAssertEqual(viewModel.currentInput, "beta")
    }

    func testMetricsRecalculatedAfterRewindAndResubmit() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["hello", "world"]))

        viewModel.type("hello")
        viewModel.handleSubmit()
        viewModel.type("wordd")
        viewModel.handleSubmit()

        XCTAssertEqual(viewModel.accuracy, 90, accuracy: 0.01)

        viewModel.handleDeleteBackward()

        XCTAssertEqual(viewModel.accuracy, 100, accuracy: 0.01)

        while !viewModel.currentInput.isEmpty {
            viewModel.handleDeleteBackward()
        }
        viewModel.type("world")
        viewModel.handleSubmit()

        XCTAssertEqual(viewModel.currentWordIndex, 2)
        XCTAssertEqual(viewModel.accuracy, 100, accuracy: 0.01)
        XCTAssertNotNil(viewModel.finishedAt)
    }

    func testCaretStateTracksCurrentInputLength() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["hello"]))

        viewModel.handleInsert("h")
        viewModel.handleInsert("e")

        XCTAssertEqual(viewModel.caretState, PracticeCaretState(wordIndex: 0, letterIndex: 2))
    }

    func testCaretStateTracksOvertypedInputLength() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["cat"]))

        viewModel.handleInsert("c")
        XCTAssertEqual(viewModel.caretState?.wordIndex, 0)
        XCTAssertEqual(viewModel.caretState?.letterIndex, 1)

        viewModel.handleInsert("a")
        XCTAssertEqual(viewModel.caretState?.wordIndex, 0)
        XCTAssertEqual(viewModel.caretState?.letterIndex, 2)

        viewModel.handleInsert("t")
        XCTAssertEqual(viewModel.caretState?.wordIndex, 0)
        XCTAssertEqual(viewModel.caretState?.letterIndex, 3)

        viewModel.handleInsert("s")
        XCTAssertEqual(viewModel.currentInput, "cats")
        XCTAssertEqual(viewModel.caretState?.wordIndex, 0)
        XCTAssertEqual(viewModel.caretState?.letterIndex, 4)

        viewModel.handleInsert("t")
        XCTAssertEqual(viewModel.currentInput, "catst")
        XCTAssertEqual(viewModel.caretState?.wordIndex, 0)
        XCTAssertEqual(viewModel.caretState?.letterIndex, 5)
    }

    func testWordRenderStatesIncludeSubmittedActiveAndUpcomingRoles() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["hello", "world", "swift"]))

        viewModel.type("hey")
        viewModel.handleSubmit()
        viewModel.type("w")

        XCTAssertEqual(viewModel.wordRenderStates.map(\.role), [.submitted, .active, .upcoming])
        XCTAssertEqual(viewModel.wordRenderStates[1].wordIndex, 1)
        XCTAssertEqual(viewModel.wordRenderStates[1].letters.map(\.role), [.correct, .pending, .pending, .pending, .pending])
    }

    func testWordRenderStatesMarkExtraTypedLettersOnActiveWord() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["cat"]))

        viewModel.type("caxt")

        let letters = viewModel.wordRenderStates[0].letters

        XCTAssertEqual(letters.map(\.character), Array("catt"))
        XCTAssertEqual(letters.map(\.role), [.correct, .correct, .incorrect, .extra])
    }

    func testCaretStateRestoresAfterRewind() {
        let viewModel = PracticeViewModel(prompt: PracticePrompt(words: ["alpha", "beta"]))

        viewModel.type("alpha")
        viewModel.handleSubmit()
        viewModel.type("beta")
        viewModel.handleSubmit()

        XCTAssertNotNil(viewModel.finishedAt)
        XCTAssertNil(viewModel.caretState)

        viewModel.handleDeleteBackward()

        XCTAssertEqual(viewModel.caretState?.wordIndex, 1)
        XCTAssertEqual(viewModel.caretState?.letterIndex, 4)
        XCTAssertEqual(viewModel.currentInput, "beta")
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

private extension PracticeViewModel {
    func type(_ text: String) {
        for character in text {
            handleInsert(character)
        }
    }
}
