import XCTest
@testable import TypingLens

@MainActor
final class AnalyticsViewModelTests: XCTestCase {
    func testShowAutoSelectsFirstWordWhenNoSelectionExists() {
        let viewModel = AnalyticsViewModel()
        let result = sampleResult(words: ["because", "their"])

        viewModel.show(result: result)

        XCTAssertEqual(viewModel.selectedWordID, "because")
        XCTAssertEqual(viewModel.selectedWord?.word, "because")
    }

    func testShowPreservesSelectionAcrossRefreshWhenWordStillExists() {
        let viewModel = AnalyticsViewModel()
        viewModel.show(result: sampleResult(words: ["because", "their"]))
        viewModel.selectedWordID = "their"

        viewModel.show(result: sampleResult(words: ["their", "because", "separate"]))

        XCTAssertEqual(viewModel.selectedWordID, "their")
        XCTAssertEqual(viewModel.selectedWord?.word, "their")
    }

    func testShowFallsBackToFirstWordWhenSelectionDisappears() {
        let viewModel = AnalyticsViewModel()
        viewModel.show(result: sampleResult(words: ["because", "their"]))
        viewModel.selectedWordID = "because"

        viewModel.show(result: sampleResult(words: ["their", "separate"]))

        XCTAssertEqual(viewModel.selectedWordID, "their")
        XCTAssertEqual(viewModel.selectedWord?.word, "their")
    }

    func testShowFallsBackToFirstWordWhenResultBecomesEmpty() {
        let viewModel = AnalyticsViewModel()
        viewModel.show(result: sampleResult(words: ["because", "their"]))

        viewModel.show(result: AnalyticsResult(analyzedAt: "2026-04-16T00:00:00Z", totalUniqueWords: 0, words: []))

        XCTAssertNil(viewModel.selectedWordID)
        XCTAssertNil(viewModel.selectedWord)
    }

    func testSelectedWordIsNilForEmptyResult() {
        let viewModel = AnalyticsViewModel()

        viewModel.show(result: AnalyticsResult(analyzedAt: "2026-04-16T00:00:00Z", totalUniqueWords: 0, words: []))

        XCTAssertNil(viewModel.selectedWord)
        XCTAssertNil(viewModel.result?.words.first)
    }

    private func sampleResult(words: [String]) -> AnalyticsResult {
        let analyticsWords: [AnalyticsWord] = words.enumerated().map { index, word in
            AnalyticsWord(
                id: word,
                rank: index + 1,
                word: word,
                characters: word.count,
                frequency: 1,
                totalErrors: 0,
                misspellingCount: 0,
                avgMsPerChar: 100,
                overallWPM: 120,
                compositeScore: Double(100 - index),
                misspellings: []
            )
        }

        return AnalyticsResult(
            analyzedAt: "2026-04-16T00:00:00Z",
            totalUniqueWords: analyticsWords.count,
            words: analyticsWords
        )
    }
}
