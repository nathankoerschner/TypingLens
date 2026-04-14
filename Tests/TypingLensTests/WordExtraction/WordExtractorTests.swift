import XCTest
@testable import TypingLens

final class WordExtractorTests: XCTestCase {
    private let extractor = WordExtractor()
    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Basic Word Extraction

    func testSimpleWordFromKeyDownSequencePlusSpace() {
        let events = keyDownEvents(for: "hello") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "hello")
        XCTAssertEqual(result.words.first?.characters, 5)
        XCTAssertEqual(result.words.first?.mistakeCount, 0)
    }

    func testMultipleWordsExtractedFromKeystrokeSequence() {
        let events = keyDownEvents(for: "hello") + [keyDown(" ")] +
            keyDownEvents(for: "world") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 2)
        XCTAssertEqual(result.words.map(\.word), ["hello", "world"])
    }

    func testTrailingWordFinalizedAtEndOfEvents() {
        let events = keyDownEvents(for: "hello")
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "hello")
    }

    // MARK: - Backspace Handling

    func testBackspaceReducesBufferAndIncrementsMistakeCount() {
        let events = keyDownEvents(for: "helo") +
            [keyDown("\u{7F}")] +
            keyDownEvents(for: "lo") +
            [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "hello")
        XCTAssertEqual(result.words.first?.mistakeCount, 1)
    }

    func testBackspaceOnEmptyBufferStillCountsMistake() {
        let events = [keyDown("\u{7F}")] + keyDownEvents(for: "hi") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "hi")
    }

    func testBackspacingThroughBoundaryDoesNotCreateFragmentWord() {
        let events = keyDownEvents(for: "hello") +
            [keyDown(" "), keyDown("\u{7F}"), keyDown("\u{7F}"), keyDown("\u{7F}")] +
            keyDownEvents(for: "orl") +
            [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.map(\.word), ["hello"])
    }

    func testRemovingExtraSpaceWithSingleBackspaceKeepsNextWord() {
        let events = keyDownEvents(for: "hello") +
            [keyDown(" "), keyDown(" "), keyDown("\u{7F}")] +
            keyDownEvents(for: "world") +
            [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 2)
        XCTAssertEqual(result.words.map(\.word), ["hello", "world"])
    }

    func testSubstantialSuffixBackspacingDoesNotEmitRemainder() {
        let events = keyDownEvents(for: "abandoning") + Array(repeating: keyDown("\u{7F}"), count: 5) + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 0)
    }

    // MARK: - Time Gap Boundary

    func testTimeGapGreaterThan2SecondsForcesWordBoundary() {
        let t1 = "2026-04-14T12:00:00.000000Z"
        let t2 = "2026-04-14T12:00:00.100000Z"
        let t3 = "2026-04-14T12:00:02.200000Z"
        let t4 = "2026-04-14T12:00:02.300000Z"

        let events = [
            makeKeyDown("h", ts: t1),
            makeKeyDown("i", ts: t2),
            makeKeyDown("b", ts: t3),
            makeKeyDown("y", ts: t4),
            makeKeyDown(" ", ts: t4),
        ]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 2)
        XCTAssertEqual(result.words.map(\.word), ["hi", "by"])
    }

    // MARK: - Modifier Handling

    func testCommandModifiedKeyDropsCurrentPartialWord() {
        let events = keyDownEvents(for: "hello") +
            [makeKeyDown("a", ts: nil, modifiers: ["command"])] +
            [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 0)
    }

    func testControlModifiedKeyDropsCurrentPartialWord() {
        let events = keyDownEvents(for: "test") +
            [makeKeyDown("c", ts: nil, modifiers: ["control"])] +
            [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 0)
    }

    func testControlModifiedShortcutBreaksCurrentWord() {
        let events = keyDownEvents(for: "su") +
            [makeKeyDown("c", ts: nil, modifiers: ["control"])] +
            keyDownEvents(for: "superbuilders") +
            [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.map(\.word), ["superbuilders"])
    }

    func testCommandModifiedShortcutBreaksCurrentWord() {
        let events = keyDownEvents(for: "he") +
            [makeKeyDown("v", ts: nil, modifiers: ["command"])] +
            keyDownEvents(for: "world") +
            [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.map(\.word), ["world"])
    }

    func testOptionBackspaceDiscardsCurrentWord() {
        let events = keyDownEvents(for: "hel") +
            [makeKeyDown("\u{7F}", ts: nil, modifiers: ["command"])] +
            keyDownEvents(for: "world") +
            [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "world")
    }

    // MARK: - Filtering

    func testSingleCharWordsAreFiltered() {
        let events = [keyDown("a"), keyDown(" "), keyDown("b"), keyDown(" ")] +
            keyDownEvents(for: "hi") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "hi")
    }

    func testPunctuationOnlyWordsAreFiltered() {
        // Each period is a boundary, so no "word" is built from punctuation
        let events = keyDownEvents(for: "...") + [keyDown(" ")] +
            keyDownEvents(for: "hi") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "hi")
    }

    // MARK: - Punctuation as Word Boundaries

    func testPeriodsActAsWordBoundaries() {
        let events = keyDownEvents(for: "hello") + [keyDown(".")] +
            keyDownEvents(for: "world") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 2)
        XCTAssertEqual(result.words.map(\.word), ["hello", "world"])
    }

    func testQuestionMarksActAsWordBoundaries() {
        let events = keyDownEvents(for: "what") + [keyDown("?")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "what")
    }

    func testExclamationMarksActAsWordBoundaries() {
        let events = keyDownEvents(for: "wow") + [keyDown("!")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "wow")
    }

    func testDashesActAsWordBoundaries() {
        let events = keyDownEvents(for: "well") + [keyDown("-")] +
            keyDownEvents(for: "known") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 2)
        XCTAssertEqual(result.words.map(\.word), ["well", "known"])
    }

    func testEmDashActsAsWordBoundary() {
        let events = keyDownEvents(for: "hello") + [keyDown("\u{2014}")] +
            keyDownEvents(for: "world") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 2)
        XCTAssertEqual(result.words.map(\.word), ["hello", "world"])
    }

    func testDoubleQuotesActAsWordBoundaries() {
        let events = [keyDown("\"")] + keyDownEvents(for: "hi") + [keyDown("\""), keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "hi")
    }

    // MARK: - Apostrophes

    func testInternalApostrophesArePreserved() {
        let events = keyDownEvents(for: "don't") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "don't")
    }

    func testLeadingTrailingApostrophesAreTrimmed() {
        let events = [keyDown("'")] + keyDownEvents(for: "hello") + [keyDown("'"), keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "hello")
    }

    // MARK: - Numbers

    func testDigitsActAsWordBoundaries() {
        let events = keyDownEvents(for: "hello") + keyDownEvents(for: "123") +
            keyDownEvents(for: "world") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 2)
        XCTAssertEqual(result.words.map(\.word), ["hello", "world"])
    }

    func testSpecialCharactersActAsWordBoundaries() {
        // +, =, ~, @, #, $, %, ^, &, *, \, |, /, <, > should all be boundaries
        for char in ["+", "=", "~", "@", "#", "$", "%", "^", "&", "*", "\\", "|", "/", "<", ">"] {
            let events = keyDownEvents(for: "ab") + [keyDown(char)] + keyDownEvents(for: "cd") + [keyDown(" ")]
            let result = extractor.extract(from: events, at: fixedDate)

            XCTAssertEqual(result.words.map(\.word), ["ab", "cd"], "Character '\(char)' should act as word boundary")
        }
    }

    func testStandaloneNumbersAreNotExtracted() {
        let events = keyDownEvents(for: "42") + [keyDown(" ")] +
            keyDownEvents(for: "hi") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        XCTAssertEqual(result.words.first?.word, "hi")
    }

    // MARK: - Duration Calculation

    func testDurationCalculatedFromFirstKeyDownToLastKeyUp() {
        let t1 = "2026-04-14T12:00:00.000000Z"
        let t2 = "2026-04-14T12:00:00.100000Z"
        let t3 = "2026-04-14T12:00:00.200000Z"
        let tUp = "2026-04-14T12:00:00.250000Z"

        let events = [
            makeKeyDown("h", ts: t1),
            makeKeyDown("e", ts: t2),
            makeKeyDown("y", ts: t3),
            makeEvent(type: .keyUp, characters: "y", ts: tUp),
            makeKeyDown(" ", ts: "2026-04-14T12:00:00.300000Z"),
        ]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.totalWords, 1)
        // Duration: t1 (0.000) to tUp (0.250) = 250ms
        XCTAssertEqual(result.words.first?.durationMs ?? 0, 250.0, accuracy: 1.0)
    }

    // MARK: - Repeat Keys

    func testRepeatKeysAreIgnored() {
        let events = [
            makeKeyDown("h", ts: nil),
            makeEvent(type: .keyDown, characters: "h", ts: nil, isRepeat: true),
            makeEvent(type: .keyDown, characters: "h", ts: nil, isRepeat: true),
            makeKeyDown("i", ts: nil),
            makeKeyDown(" ", ts: nil),
        ]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.words.first?.word, "hi")
    }

    // MARK: - Metadata

    func testExtractedAtUsesProvidedDate() {
        let events = keyDownEvents(for: "hello") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.extractedAt, TimestampFormatter.string(from: fixedDate))
    }

    func testEmptyEventsProducesEmptyResult() {
        let result = extractor.extract(from: [], at: fixedDate)

        XCTAssertEqual(result.totalWords, 0)
        XCTAssertEqual(result.words, [])
    }

    // MARK: - Nil Characters

    func testNilCharactersEventsAreSkipped() {
        let events = [
            makeEvent(type: .keyDown, characters: nil, ts: nil),
        ] + keyDownEvents(for: "hi") + [keyDown(" ")]
        let result = extractor.extract(from: events, at: fixedDate)

        XCTAssertEqual(result.words.first?.word, "hi")
    }

    // MARK: - Helpers

    private var seqCounter: Int64 = 0

    private func nextSeq() -> Int64 {
        seqCounter += 1
        return seqCounter
    }

    private func keyDown(_ char: String) -> TranscriptEvent {
        makeKeyDown(char, ts: nil)
    }

    private func keyDownEvents(for text: String) -> [TranscriptEvent] {
        text.map { keyDown(String($0)) }
    }

    private func makeKeyDown(_ char: String, ts: String? = nil, modifiers: [String] = []) -> TranscriptEvent {
        makeEvent(type: .keyDown, characters: char, ts: ts, modifiers: modifiers)
    }

    private func makeEvent(
        type: EventType,
        characters: String?,
        ts: String?,
        modifiers: [String] = [],
        isRepeat: Bool = false
    ) -> TranscriptEvent {
        TranscriptEvent(
            seq: nextSeq(),
            ts: ts ?? "2026-04-14T12:00:00.000000Z",
            type: type,
            keyCode: 0,
            characters: characters,
            charactersIgnoringModifiers: characters,
            modifiers: modifiers,
            isRepeat: isRepeat,
            keyboardLayout: nil
        )
    }
}
