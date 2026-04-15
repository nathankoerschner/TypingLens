import Foundation
import XCTest
@testable import TypingLens

final class WordInterpreterTests: XCTestCase {
    func testInterpreterAcceptsExactMatch() {
        let service = WordInterpreter(
            lexicon: WordLexicon(
                orderedWords: [
                    "hello",
                    "world",
                    "test",
                    "typing"
                ]
            )
        )

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

    func testInterpreterCorrectsKnownTypoFromResolver() {
        let service = WordInterpreter(
            lexicon: WordLexicon(
                orderedWords: [
                    "the"
                ]
            )
        )

        let input = ExtractedWord(
            word: "teh",
            characters: 3,
            durationMs: 1200,
            mistakeCount: 1
        )

        let decision = service.interpret(input)

        guard case let .corrected(_, corrected, penalty) = decision else {
            return XCTFail("Expected corrected for known typo")
        }

        XCTAssertEqual(corrected, "the")
        XCTAssertEqual(penalty, 1)
    }

    func testInterpreterDropsGibberish() {
        let service = WordInterpreter(
            lexicon: WordLexicon(
                orderedWords: [
                    "hello",
                    "world",
                    "test",
                    "typing"
                ]
            )
        )

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

    func testInterpreterNormalizesCaseAndApostrophesBeforeLookup() {
        let service = WordInterpreter(
            lexicon: WordLexicon(orderedWords: ["hello"]),
            typoResolver: nil
        )

        let input = ExtractedWord(
            word: "\u{2019}HeLLo\u{2019}",
            characters: 5,
            durationMs: 900,
            mistakeCount: 0
        )

        let interpreted = service.interpret([input])

        XCTAssertEqual(interpreted.words.first?.normalizedWord, "hello")
        XCTAssertEqual(interpreted.correctedCount, 0)
        XCTAssertEqual(interpreted.droppedCount, 0)
        XCTAssertEqual(interpreted.words.first?.wasCorrected, false)
    }

    func testExactLexiconWordDoesNotInvokeResolver() {
        let resolver = SpyTypoResolver { _ in
            XCTFail("resolver should not be called for exact lexicon hits")
            return .dropped(.notInLexicon)
        }

        let interpreter = WordInterpreter(
            lexicon: WordLexicon(orderedWords: ["hello", "world"]),
            typoResolver: resolver
        )

        let result = interpreter.interpret([
            ExtractedWord(word: "Hello", characters: 5, durationMs: 120, mistakeCount: 0)
        ])

        XCTAssertEqual(result.words.map(\.normalizedWord), ["hello"])
        XCTAssertTrue(resolver.resolvedTokens.isEmpty)
    }

    func testRepeatedUnknownTokenResolvesOncePerNormalizedToken() {
        let resolver = SpyTypoResolver { token in
            token == "teh" ? .corrected("the", inferredPenalty: 1) : .dropped(.notInLexicon)
        }

        let interpreter = WordInterpreter(
            lexicon: WordLexicon(orderedWords: ["the"]),
            typoResolver: resolver
        )

        let result = interpreter.interpret([
            ExtractedWord(word: "teh", characters: 3, durationMs: 100, mistakeCount: 0),
            ExtractedWord(word: "Teh", characters: 3, durationMs: 120, mistakeCount: 0),
            ExtractedWord(word: "the", characters: 3, durationMs: 140, mistakeCount: 0)
        ])

        XCTAssertEqual(result.words.map(\.normalizedWord), ["the", "the", "the"])
        XCTAssertEqual(resolver.resolvedTokens.count, 1)
        XCTAssertEqual(Set(resolver.resolvedTokens), ["teh"])
    }

    func testUnknownTokenNotInTypoMapDrops() {
        let interpreter = WordInterpreter(
            lexicon: WordLexicon(orderedWords: ["hello"]),
            typoResolver: MapTypoResolver(corrections: [:])
        )

        let decision = interpreter.interpret(
            ExtractedWord(
                word: "qwerty",
                characters: 6,
                durationMs: 120,
                mistakeCount: 0
            )
        )

        guard case let .dropped(_, reason) = decision else {
            return XCTFail("Expected dropped for token not in typo map")
        }

        XCTAssertEqual(reason, .notInLexicon)
    }
}

private final class SpyTypoResolver: TypoResolver {
    private(set) var resolvedTokens: [String] = []
    private let handler: (String) -> TypoResolution

    init(handler: @escaping (String) -> TypoResolution) {
        self.handler = handler
    }

    func resolve(_ token: String) -> TypoResolution {
        resolvedTokens.append(token)
        return handler(token)
    }
}
