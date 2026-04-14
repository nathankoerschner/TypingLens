import Foundation
import XCTest
@testable import TypingLens

final class WordRankerTests: XCTestCase {
    private let ranker = WordRanker()
    private let fixedDate = Date(timeIntervalSince1970: 0)

    // MARK: - Grouping

    func testCaseInsensitiveGroupingMergesVariants() {
        let words = [
            word("The", duration: 100, mistakes: 0),
            word("the", duration: 120, mistakes: 0),
            word("THE", duration: 110, mistakes: 0),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.totalUniqueWords, 1)
        XCTAssertEqual(result.words.first?.word, "the")
        XCTAssertEqual(result.words.first?.frequency, 3)
    }

    // MARK: - Outlier Removal

    func testOutlierRemovalDropsSlowInstance() {
        let words = [
            word("test", duration: 100, mistakes: 0),
            word("test", duration: 110, mistakes: 0),
            word("test", duration: 5000, mistakes: 0),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.frequency, 2,
                       "Outlier instance should be removed")
    }

    func testOutlierRemovalDropsHighMistakeInstance() {
        let words = [
            word("test", duration: 100, mistakes: 0),
            word("test", duration: 110, mistakes: 1),
            word("test", duration: 120, mistakes: 10),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.frequency, 2)
    }

    func testGroupsWithFewerThanThreeKeepAllInstances() {
        let words = [
            word("hi", duration: 100, mistakes: 0),
            word("hi", duration: 9000, mistakes: 0),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.frequency, 2)
    }

    func testGroupReducedToZeroAfterOutlierRemovalIsDropped() {
        let words = [
            word("ab", duration: 100, mistakes: 10),
            word("ab", duration: 110, mistakes: 10),
            word("ab", duration: 120, mistakes: 10),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.totalUniqueWords, 0)
    }

    // MARK: - Normalization

    func testSingleWordNormalizesToZeroScore() {
        let words = [word("only", duration: 200, mistakes: 1)]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.compositeScore, 0.0,
                       "Single word has no range, all normalized values should be 0")
    }

    // MARK: - Scoring & Ordering

    func testSlowestMostErrorWordRanksFirst() {
        let words = [
            word("fast", duration: 50, mistakes: 0),
            word("fast", duration: 55, mistakes: 0),
            word("slow", duration: 500, mistakes: 3),
            word("slow", duration: 520, mistakes: 4),
        ]
        let result = ranker.rank(words, at: fixedDate)

        XCTAssertEqual(result.words.first?.word, "slow")
        XCTAssertGreaterThan(result.words.first!.compositeScore, result.words.last!.compositeScore)
    }

    // MARK: - Edge Cases

    func testEmptyInputReturnsEmptyResult() {
        let result = ranker.rank([], at: fixedDate)

        XCTAssertEqual(result.totalUniqueWords, 0)
        XCTAssertTrue(result.words.isEmpty)
    }

    // MARK: - Helper

    private func word(_ text: String, duration: Double, mistakes: Int) -> ExtractedWord {
        ExtractedWord(
            word: text,
            characters: text.count,
            durationMs: duration,
            mistakeCount: mistakes
        )
    }
}
