import Foundation
import XCTest
@testable import TypingLens

final class AnalyticsServiceTests: XCTestCase {
    func testAnalyzePreservesRankedOrderAndAssignsRanks() throws {
        let (locations, _) = try setupTempTranscript(
            events: transcriptEvents(for: [
                ("the", 0.01),
                ("world", 1.0),
                ("the", 0.01),
                ("world", 1.0),
            ])
        )
        let service = AnalyticsService(
            fileLocations: locations,
            interpreter: WordInterpreter(
                lexicon: WordLexicon(orderedWords: ["the", "world"]),
                typoResolver: nil
            )
        )

        let result = try service.analyze()

        XCTAssertEqual(result.words.map(\.rank), Array(1...result.words.count))
        XCTAssertEqual(result.words.map(\.compositeScore), result.words.map(\.compositeScore).sorted(by: >))
        XCTAssertEqual(result.words.first?.word, "world")
    }

    func testAnalyzeAggregatesErrorsMisspellingsAndVariantsForCorrectedWords() throws {
        let (locations, _) = try setupTempTranscript(
            events: transcriptEvents(for: ["the", "teh", "teh"])
        )

        let service = AnalyticsService(
            fileLocations: locations,
            interpreter: WordInterpreter(
                lexicon: WordLexicon(orderedWords: ["the"]),
                typoResolver: MapTypoResolver(corrections: ["teh": "the"])
            )
        )

        let result = try service.analyze()
        let the = try XCTUnwrap(result.words.first(where: { $0.word == "the" }))

        XCTAssertEqual(the.rank, 1)
        XCTAssertEqual(the.frequency, 3)
        XCTAssertEqual(the.misspellingCount, 2)
        XCTAssertEqual(the.misspellings.map(\.typed), ["teh"])
        XCTAssertEqual(the.misspellings.map(\.count), [2])
        XCTAssertGreaterThan(the.totalErrors, 0)
    }

    func testAnalyzeReturnsEmptyResultForEmptyTranscript() throws {
        let (locations, _) = try setupTempTranscript(events: transcriptEvents(for: []))

        let result = try AnalyticsService(fileLocations: locations).analyze()

        XCTAssertEqual(result.totalUniqueWords, 0)
        XCTAssertTrue(result.words.isEmpty)
    }

    func testAnalyzeReturnsEmptyResultWithStableSummaryFields() throws {
        let (locations, _) = try setupTempTranscript(events: transcriptEvents(for: []))

        let result = try AnalyticsService(fileLocations: locations).analyze()

        XCTAssertEqual(result.totalUniqueWords, 0)
        XCTAssertTrue(result.words.isEmpty)
        XCTAssertFalse(result.analyzedAt.isEmpty)
    }

    func testAnalyzeComputesOverallWPMFromAvgMsPerChar() throws {
        let (locations, _) = try setupTempTranscript(
            events: transcriptEvents(for: ["hello", "hello"])
        )

        let service = AnalyticsService(
            fileLocations: locations,
            interpreter: WordInterpreter(
                lexicon: WordLexicon(orderedWords: ["hello"]),
                typoResolver: nil
            )
        )

        let result = try service.analyze()
        let hello = try XCTUnwrap(result.words.first)

        XCTAssertEqual(
            hello.overallWPM,
            12_000 / hello.avgMsPerChar,
            accuracy: 0.0001
        )
    }

    func testAnalyzeMisspellingVariantsSortedByCountThenTyped() throws {
        let (locations, _) = try setupTempTranscript(
            events: transcriptEvents(for: ["the", "teh", "teh", "thex", "thex", "tey"])
        )

        let service = AnalyticsService(
            fileLocations: locations,
            interpreter: WordInterpreter(
                lexicon: WordLexicon(orderedWords: ["the"]),
                typoResolver: MapTypoResolver(corrections: [
                    "teh": "the",
                    "thex": "the",
                    "tey": "the"
                ])
            )
        )

        let result = try service.analyze()
        let the = try XCTUnwrap(result.words.first(where: { $0.word == "the" }))

        XCTAssertEqual(
            the.misspellings.map(\.typed),
            ["teh", "thex", "tey"]
        )
        XCTAssertEqual(the.misspellings.map(\.count), [2, 2, 1])
    }

    func testAnalyzeOmitsGibberishTokensFromAggregation() throws {
        let (locations, _) = try setupTempTranscript(
            events: transcriptEvents(for: ["hello", "jjjjkjj", "world"])
        )

        let service = AnalyticsService(
            fileLocations: locations,
            interpreter: WordInterpreter(
                lexicon: WordLexicon(orderedWords: ["hello", "world"]),
                typoResolver: nil
            )
        )

        let result = try service.analyze()

        let words = result.words.map(\.word)
        XCTAssertEqual(Set(words), ["hello", "world"])
        XCTAssertFalse(words.contains("jjjjkjj"))
    }

    func testAnalyzeReturnsZeroWPMWhenAvgMsPerCharIsNonPositive() throws {
        let (locations, _) = try setupTempTranscript(
            events: transcriptEvents(for: [("teh", 0.0)], gapBetweenCharacters: 0)
        )

        let service = AnalyticsService(
            fileLocations: locations,
            interpreter: WordInterpreter(
                lexicon: WordLexicon(orderedWords: ["teh"]),
                typoResolver: nil
            )
        )

        let result = try service.analyze()
        let word = try XCTUnwrap(result.words.first)

        XCTAssertEqual(word.avgMsPerChar, 0)
        XCTAssertEqual(word.overallWPM, 0)
    }

    // MARK: - Helpers

    private func setupTempTranscript(
        events: [TranscriptEvent]
    ) throws -> (FileLocations, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let locations = FileLocations(appSupportBaseURL: tempDir)
        try FileManager.default.createDirectory(
            at: locations.appDirectoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder.transcriptEncoder()
        let lines = try events.map { event in
            let data = try encoder.encode(event)
            return String(data: data, encoding: .utf8)!
        }
        let content = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        try content.write(to: locations.transcriptURL, atomically: true, encoding: .utf8)

        return (locations, tempDir)
    }

    private func transcriptEvents(for words: [String], charGap: Double = 0.05, gapBetweenCharacters: Double = 0.05) -> [TranscriptEvent] {
        transcriptEvents(for: words.map { ($0, charGap) }, gapBetweenCharacters: gapBetweenCharacters)
    }

    private func transcriptEvents(for words: [(String, Double)], gapBetweenCharacters: Double = 0.05) -> [TranscriptEvent] {
        var seq: Int64 = 0
        var timeOffset: Double = 0
        let baseTime = Date(timeIntervalSince1970: 1_000_000)

        func next() -> Int64 {
            seq += 1
            return seq
        }

        func ts() -> String {
            return TimestampFormatter.string(from: baseTime.addingTimeInterval(timeOffset))
        }

        func keyDown(_ char: String) -> TranscriptEvent {
            defer { timeOffset += gapBetweenCharacters }
            return TranscriptEvent(
                seq: next(),
                ts: ts(),
                type: .keyDown,
                keyCode: 0,
                characters: char,
                charactersIgnoringModifiers: char,
                modifiers: [],
                isRepeat: false,
                keyboardLayout: nil
            )
        }

        var events: [TranscriptEvent] = []
        for (word, charGap) in words {
            for character in word {
                events.append(keyDown(String(character)))
                timeOffset += charGap - gapBetweenCharacters
            }
            events.append(keyDown(" "))
        }

        return events
    }
}
