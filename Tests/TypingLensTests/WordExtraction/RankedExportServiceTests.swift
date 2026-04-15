import Foundation
import XCTest
@testable import TypingLens

final class RankedExportServiceTests: XCTestCase {
    func testRunProducesRankedWordsFile() throws {
        let (locations, _) = try setupTempTranscript(events: sampleTypingEvents())
        let service = RankedExportService(fileLocations: locations)

        let result = try service.run()

        XCTAssertGreaterThan(result.totalUniqueWords, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locations.rankedWordsURL.path))

        let outputData = try Data(contentsOf: locations.rankedWordsURL)
        let decoded = try JSONDecoder().decode(RankedWordResult.self, from: outputData)
        XCTAssertEqual(decoded.totalUniqueWords, result.totalUniqueWords)
    }

    func testRunDoesNotWriteExtractedWordsFileAsSideEffect() throws {
        let (locations, _) = try setupTempTranscript(events: sampleTypingEvents())
        let service = RankedExportService(fileLocations: locations)

        _ = try service.run()

        XCTAssertTrue(FileManager.default.fileExists(atPath: locations.rankedWordsURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: locations.extractedWordsURL.path))
    }

    func testOutputIsSortedByDescendingCompositeScore() throws {
        let (locations, _) = try setupTempTranscript(events: sampleTypingEvents())
        let service = RankedExportService(fileLocations: locations)

        let result = try service.run()

        let scores = result.words.map(\.compositeScore)
        XCTAssertEqual(scores, scores.sorted(by: >),
                       "Words should be sorted by descending composite score")
    }

    func testRunWithEmptyTranscriptProducesZeroWords() throws {
        let (locations, _) = try setupTempTranscript(events: [])
        let service = RankedExportService(fileLocations: locations)

        let result = try service.run()

        XCTAssertEqual(result.totalUniqueWords, 0)
        XCTAssertTrue(result.words.isEmpty)
    }

    func testRunThrowsWhenTranscriptMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let service = RankedExportService(fileLocations: locations)

        XCTAssertThrowsError(try service.run())
    }

    func testRunMergesCorrectableTyposIntoCorrectWord() throws {
        let (locations, _) = try setupTempTranscript(events: transcriptEvents(for: ["the", "teh", "the"]))
        let service = RankedExportService(fileLocations: locations)

        let result = try service.run()

        XCTAssertEqual(result.totalUniqueWords, 1)
        XCTAssertEqual(result.words.first?.word, "the")
        XCTAssertEqual(result.words.first?.frequency, 3)
    }

    func testRunDropsGibberishFromRankedOutput() throws {
        let (locations, _) = try setupTempTranscript(events: transcriptEvents(for: ["hello", "jjjjkjj", "world"]))
        let service = RankedExportService(fileLocations: locations)

        let result = try service.run()

        let words = result.words.map(\.word)
        XCTAssertEqual(Set(words), ["hello", "world"])
        XCTAssertFalse(words.contains("jjjjkjj"))
    }

    // MARK: - Helpers

    private func setupTempTranscript(events: [TranscriptEvent]) throws -> (FileLocations, URL) {
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

    private func sampleTypingEvents() -> [TranscriptEvent] {
        var seq: Int64 = 0
        var timeOffset: Double = 0
        let baseTime = Date(timeIntervalSince1970: 1_000_000)

        func next() -> Int64 { seq += 1; return seq }
        func ts() -> String {
            timeOffset += 0.05
            return TimestampFormatter.string(from: baseTime.addingTimeInterval(timeOffset))
        }

        func keyDown(_ char: String) -> TranscriptEvent {
            TranscriptEvent(
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

        // Type "hello" twice (fast) and "world" twice (slow, with mistakes)
        var events: [TranscriptEvent] = []
        for _ in 0..<2 {
            events += "hello".map { keyDown(String($0)) } + [keyDown(" ")]
        }
        timeOffset += 0.5 // slower typing for "world"
        for _ in 0..<2 {
            events += "world".map { keyDown(String($0)) }
            events.append(keyDown("\u{7F}")) // backspace = mistake
            events += [keyDown("d"), keyDown(" ")]
        }
        return events
    }

    private func transcriptEvents(for words: [String]) -> [TranscriptEvent] {
        var seq: Int64 = 0
        var timeOffset: Double = 0
        let baseTime = Date(timeIntervalSince1970: 1_000_000)

        func next() -> Int64 { seq += 1; return seq }
        func ts() -> String {
            timeOffset += 0.05
            return TimestampFormatter.string(from: baseTime.addingTimeInterval(timeOffset))
        }

        func keyDown(_ char: String) -> TranscriptEvent {
            TranscriptEvent(
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
        for word in words {
            events += word.map { keyDown(String($0)) }
            events.append(keyDown(" "))
        }

        return events
    }
}
