import Foundation
import XCTest
@testable import TypingLens

final class PracticePromptBuilderTests: XCTestCase {
    func testEmptyRankedInputReturnsEmptyPrompt() {
        let ranked = RankedWordResult(analyzedAt: "", totalUniqueWords: 0, words: [])
        let builder = PracticePromptBuilder()

        let prompt = builder.build(from: ranked)

        XCTAssertTrue(prompt.words.isEmpty)
    }

    func testBuildHonorsWordCount() {
        let ranked = RankedWordResult(
            analyzedAt: "",
            totalUniqueWords: 3,
            words: [
                rankedWord("focus", 3),
                rankedWord("swift", 2),
                rankedWord("code", 1)
            ]
        )
        let builder = PracticePromptBuilder()

        let prompt = builder.build(from: ranked, wordCount: 7)

        XCTAssertEqual(prompt.words.count, 7)
    }

    func testSingleWordRepeatsToRequestedLength() {
        let ranked = RankedWordResult(
            analyzedAt: "",
            totalUniqueWords: 1,
            words: [
                rankedWord("focus", 0)
            ]
        )
        let builder = PracticePromptBuilder()

        let prompt = builder.build(from: ranked, wordCount: 5)

        XCTAssertEqual(prompt.words, ["focus", "focus", "focus", "focus", "focus"])
    }

    func testImmediateDuplicatesAreAvoidedWhenAlternativeWordsExist() {
        let ranked = RankedWordResult(
            analyzedAt: "",
            totalUniqueWords: 3,
            words: [
                rankedWord("focus", 3),
                rankedWord("swift", 2),
                rankedWord("code", 1)
            ]
        )
        let builder = PracticePromptBuilder()

        let prompt = builder.build(from: ranked, wordCount: 30)

        for index in 1..<prompt.words.count {
            XCTAssertNotEqual(prompt.words[index - 1], prompt.words[index])
        }
    }

    func testHigherWeightedWordsAppearMoreOftenAcrossPrompt() {
        let ranked = RankedWordResult(
            analyzedAt: "",
            totalUniqueWords: 4,
            words: [
                rankedWord("focus", 100),
                rankedWord("swift", 10),
                rankedWord("code", 1),
                rankedWord("test", 1)
            ]
        )
        let builder = PracticePromptBuilder()

        let prompt = builder.build(from: ranked, wordCount: 1000).words

        let focusCount = prompt.filter { $0 == "focus" }.count
        let swiftCount = prompt.filter { $0 == "swift" }.count
        let codeCount = prompt.filter { $0 == "code" }.count

        XCTAssertGreaterThan(focusCount, swiftCount)
        XCTAssertGreaterThan(swiftCount, codeCount)
    }

    func testOnlyTopThirtyWordsAreUsedAsPromptSource() {
        let ranked = RankedWordResult(
            analyzedAt: "",
            totalUniqueWords: 40,
            words: (0..<40).map { index in
                let score = Double(40 - index)
                return rankedWord("word\(index + 1)", score)
            }
        )

        let builder = PracticePromptBuilder()
        let prompt = builder.build(from: ranked, wordCount: 200).words

        XCTAssertFalse(prompt.contains("word31"))
        XCTAssertFalse(prompt.contains("word32"))
        XCTAssertFalse(prompt.contains("word33"))
        XCTAssertFalse(prompt.contains("word40"))
    }

    // MARK: - Helpers

    private func rankedWord(_ word: String, _ score: Double) -> RankedWord {
        RankedWord(
            word: word,
            characters: word.count,
            frequency: 1,
            avgMsPerChar: 100,
            errorRate: 0.0,
            compositeScore: score
        )
    }
}
