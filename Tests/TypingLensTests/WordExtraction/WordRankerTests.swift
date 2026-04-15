import Foundation
import XCTest
@testable import TypingLens

final class WordRankerTests: XCTestCase {
    private let ranker = WordRanker()
    private let fixedDate = Date(timeIntervalSince1970: 0)

    // MARK: - Grouping

    func testGroupingMergesNormalizedWordsIntoSingleEntry() {
        let words = [
            interpreted("the", original: "The", duration: 100, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("the", original: "the", duration: 120, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("the", original: "THE", duration: 110, transcriptMistakes: 0, inferredPenalty: 0),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.totalUniqueWords, 1)
        XCTAssertEqual(result.words.first?.word, "the")
        XCTAssertEqual(result.words.first?.frequency, 3)
    }

    // MARK: - Outlier Removal

    func testOutlierRemovalDropsSlowInstance() {
        let words = [
            interpreted("test", original: "test", duration: 100, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("test", original: "test", duration: 110, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("test", original: "test", duration: 5000, transcriptMistakes: 0, inferredPenalty: 0),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.frequency, 2,
                       "Outlier instance should be removed")
    }

    func testOutlierRemovalDropsHighMistakeInstance() {
        let words = [
            interpreted("test", original: "test", duration: 100, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("test", original: "test", duration: 110, transcriptMistakes: 1, inferredPenalty: 0),
            interpreted("test", original: "test", duration: 120, transcriptMistakes: 10, inferredPenalty: 0),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.frequency, 2)
    }

    func testGroupsWithFewerThanThreeKeepAllInstances() {
        let words = [
            interpreted("hi", original: "hi", duration: 100, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("hi", original: "hi", duration: 9000, transcriptMistakes: 0, inferredPenalty: 0),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.frequency, 2)
    }

    func testGroupReducedToZeroAfterOutlierRemovalIsDropped() {
        let words = [
            interpreted("ab", original: "ab", duration: 100, transcriptMistakes: 10, inferredPenalty: 0),
            interpreted("ab", original: "ab", duration: 110, transcriptMistakes: 10, inferredPenalty: 0),
            interpreted("ab", original: "ab", duration: 120, transcriptMistakes: 10, inferredPenalty: 0),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.totalUniqueWords, 0)
    }

    // MARK: - Normalization

    func testSingleWordNormalizesToZeroScore() {
        let words = [interpreted("only", original: "only", duration: 200, transcriptMistakes: 1, inferredPenalty: 0)]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.compositeScore, 0.0,
                       "Single word has no range, all normalized values should be 0")
    }

    // MARK: - Scoring & Ordering

    func testSlowestMostErrorWordRanksFirst() {
        let words = [
            interpreted("fast", original: "fast", duration: 50, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("fast", original: "fast", duration: 55, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("slow", original: "slow", duration: 500, transcriptMistakes: 3, inferredPenalty: 0),
            interpreted("slow", original: "slow", duration: 520, transcriptMistakes: 4, inferredPenalty: 0),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.word, "slow")
        XCTAssertGreaterThan(result.words.first!.compositeScore, result.words.last!.compositeScore)
    }

    // MARK: - Phase 2 Coverage

    func testCorrectedAndAcceptedWordsMergeUnderNormalizedWord() {
        let words = [
            interpreted("the", original: "the", duration: 100, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("the", original: "teh", duration: 140, transcriptMistakes: 0, inferredPenalty: 1),
            interpreted("the", original: "The", duration: 110, transcriptMistakes: 0, inferredPenalty: 0)
        ]

        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.totalUniqueWords, 1)
        XCTAssertEqual(result.words.first?.word, "the")
        XCTAssertEqual(result.words.first?.frequency, 3)
    }

    func testInferredPenaltyContributesToErrorRate() {
        let words = [
            interpreted("the", original: "the", duration: 100, transcriptMistakes: 0, inferredPenalty: 0),
            interpreted("the", original: "teh", duration: 120, transcriptMistakes: 0, inferredPenalty: 1)
        ]

        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.errorRate ?? 0, 1.0 / 6.0, accuracy: 0.0001)
    }

    // MARK: - Edge Cases

    func testEmptyInputReturnsEmptyResult() {
        let result = ranker.rank([] as [InterpretedWord], at: fixedDate)

        XCTAssertEqual(result.totalUniqueWords, 0)
        XCTAssertTrue(result.words.isEmpty)
    }

    // MARK: - Helper

    private func interpreted(
        _ normalized: String,
        original: String,
        duration: Double,
        transcriptMistakes: Int,
        inferredPenalty: Int
    ) -> InterpretedWord {
        InterpretedWord(
            originalWord: original,
            normalizedWord: normalized,
            characters: normalized.count,
            durationMs: duration,
            transcriptMistakeCount: transcriptMistakes,
            inferredSpellingPenalty: inferredPenalty,
            wasCorrected: inferredPenalty > 0 || original != normalized
        )
    }
}
