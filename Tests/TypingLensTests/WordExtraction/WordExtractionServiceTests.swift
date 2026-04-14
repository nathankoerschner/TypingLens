import Foundation
import XCTest
@testable import TypingLens

final class WordExtractionServiceTests: XCTestCase {
    func testRunProducesOutputFileWithExtractedWords() throws {
        let (locations, _) = try setupTempTranscript(events: sampleEvents())
        let service = WordExtractionService(fileLocations: locations)

        let result = try service.run()

        XCTAssertGreaterThan(result.totalWords, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locations.extractedWordsURL.path))

        let outputData = try Data(contentsOf: locations.extractedWordsURL)
        let decoded = try JSONDecoder().decode(WordExtractionResult.self, from: outputData)
        XCTAssertEqual(decoded.totalWords, result.totalWords)
        XCTAssertEqual(decoded.words.map(\.word), result.words.map(\.word))
    }

    func testExtractInMemoryDoesNotCreateOutputFile() throws {
        let (locations, _) = try setupTempTranscript(events: sampleEvents())
        let service = WordExtractionService(fileLocations: locations)

        let result = try service.extractInMemory()

        XCTAssertGreaterThan(result.totalWords, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: locations.extractedWordsURL.path))
    }

    func testWriteToFilePersistsProvidedExtractionResult() throws {
        let (locations, _) = try setupTempTranscript(events: sampleEvents())
        let service = WordExtractionService(fileLocations: locations)
        let result = try service.extractInMemory()

        try service.writeToFile(result)

        XCTAssertTrue(FileManager.default.fileExists(atPath: locations.extractedWordsURL.path))

        let outputData = try Data(contentsOf: locations.extractedWordsURL)
        let decoded = try JSONDecoder().decode(WordExtractionResult.self, from: outputData)
        XCTAssertEqual(decoded.totalWords, result.totalWords)
        XCTAssertEqual(decoded.words.map(\.word), result.words.map(\.word))
    }

    func testRunWithEmptyTranscriptProducesZeroWords() throws {
        let (locations, _) = try setupTempTranscript(events: [])
        let service = WordExtractionService(fileLocations: locations)

        let result = try service.run()

        XCTAssertEqual(result.totalWords, 0)
        XCTAssertEqual(result.words, [])
    }

    func testRunThrowsWhenTranscriptMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let service = WordExtractionService(fileLocations: locations)

        XCTAssertThrowsError(try service.run()) { error in
            XCTAssertEqual(error as? WordExtractionError, .transcriptNotFound)
        }
    }

    func testOutputFileIsValidPrettyPrintedJSON() throws {
        let (locations, _) = try setupTempTranscript(events: sampleEvents())
        let service = WordExtractionService(fileLocations: locations)
        _ = try service.run()

        let outputString = try String(contentsOf: locations.extractedWordsURL, encoding: .utf8)
        XCTAssertTrue(outputString.contains("\n"), "Output should be pretty-printed")
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

    private func sampleEvents() -> [TranscriptEvent] {
        let ts = "2026-04-14T12:00:00.000000Z"
        var seq: Int64 = 0
        func next() -> Int64 { seq += 1; return seq }

        func keyDown(_ char: String) -> TranscriptEvent {
            TranscriptEvent(
                seq: next(),
                ts: ts,
                type: .keyDown,
                keyCode: 0,
                characters: char,
                charactersIgnoringModifiers: char,
                modifiers: [],
                isRepeat: false,
                keyboardLayout: nil
            )
        }

        // "hello world"
        return "hello".map { keyDown(String($0)) } + [keyDown(" ")] +
               "world".map { keyDown(String($0)) } + [keyDown(" ")]
    }
}
