import Foundation
import XCTest
@testable import TypingLens

final class WordInterpreterTests: XCTestCase {
    private let lexicon = WordLexicon(
        orderedWords: [
            "hello",
            "world",
            "test",
            "typing"
        ]
    )

    func testInterpreterAcceptsExactMatch() {
        let service = WordInterpreter(lexicon: lexicon)

        let input = ExtractedWord(
            word: "Hello",
            characters: 5,
            durationMs: 1200,
            mistakeCount: 0
        )

        let decision = service.interpret(input)

        guard case let .accepted(normalized) = decision else {
            return XCTFail("Expected accepted for exact lexicon match")
        }

        XCTAssertEqual(normalized, "hello")
    }

    func testInterpreterCorrectsCommonTypos() {
        let service = WordInterpreter(lexicon: lexicon)

        let input = ExtractedWord(
            word: "helo",
            characters: 4,
            durationMs: 1200,
            mistakeCount: 1
        )

        let decision = service.interpret(input)

        guard case let .corrected(_, corrected, penalty) = decision else {
            return XCTFail("Expected corrected for typo-like word")
        }

        XCTAssertEqual(corrected, "hello")
        XCTAssertEqual(penalty, 1)
    }

    func testInterpreterDropsGibberish() {
        let service = WordInterpreter(lexicon: lexicon)

        let input = ExtractedWord(
            word: "aaaaab",
            characters: 6,
            durationMs: 100,
            mistakeCount: 0
        )

        let decision = service.interpret(input)

        guard case .dropped = decision else {
            return XCTFail("Expected gibberish token to be dropped")
        }
    }

    func testInterpreterPreservesApostrophes() {
        let service = WordInterpreter(lexicon: lexicon)

        let input = ExtractedWord(
            word: "Typing",
            characters: 6,
            durationMs: 900,
            mistakeCount: 0
        )

        let interpreted = service.interpret([input])

        XCTAssertEqual(interpreted.words.first?.normalizedWord, "typing")
        XCTAssertEqual(interpreted.correctedCount, 0)
        XCTAssertEqual(interpreted.droppedCount, 0)
        XCTAssertEqual(interpreted.words.first?.wasCorrected, false)
    }
}
