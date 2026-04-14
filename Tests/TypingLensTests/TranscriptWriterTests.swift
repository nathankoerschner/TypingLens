import Foundation
import XCTest
@testable import TypingLens

final class TranscriptWriterTests: XCTestCase {
    func testInitializeNextSequenceReturnsOneForEmptyTranscript() throws {
        let tempDir = try temporaryDirectory()
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let writer = TranscriptWriter(fileLocations: locations)

        XCTAssertEqual(try writer.initializeNextSequence(), 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locations.transcriptURL.path))
    }

    func testAppendWritesCompactJsonLineWithNewlineTermination() throws {
        let tempDir = try temporaryDirectory()
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let writer = TranscriptWriter(fileLocations: locations)

        try writer.append(sampleEvent(seq: 41))

        let data = try Data(contentsOf: locations.transcriptURL)
        let string = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(string.hasSuffix("\n"))
        XCTAssertFalse(string.contains("\n\n"))
        XCTAssertFalse(string.contains(" "))

        let decoded = try JSONDecoder().decode(TranscriptEvent.self, from: Data(string.dropLast().utf8))
        XCTAssertEqual(decoded, sampleEvent(seq: 41))
    }

    func testInitializeNextSequenceUsesLastPersistedLine() throws {
        let tempDir = try temporaryDirectory()
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let writer = TranscriptWriter(fileLocations: locations)

        try writer.append(sampleEvent(seq: 41))
        try writer.append(sampleEvent(seq: 42))

        XCTAssertEqual(try writer.initializeNextSequence(), 43)
    }

    func testClearTranscriptEmptiesFileButKeepsItPresent() throws {
        let tempDir = try temporaryDirectory()
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let writer = TranscriptWriter(fileLocations: locations)

        try writer.append(sampleEvent(seq: 41))
        try writer.clearTranscript()

        XCTAssertTrue(FileManager.default.fileExists(atPath: locations.transcriptURL.path))
        let data = try Data(contentsOf: locations.transcriptURL)
        XCTAssertEqual(data.count, 0)
    }

    func testAppendRecreatesTranscriptAfterDeletion() throws {
        let tempDir = try temporaryDirectory()
        let locations = FileLocations(appSupportBaseURL: tempDir)
        let writer = TranscriptWriter(fileLocations: locations)

        try writer.append(sampleEvent(seq: 41))
        try FileManager.default.removeItem(at: locations.transcriptURL)
        try writer.append(sampleEvent(seq: 42))

        let data = try Data(contentsOf: locations.transcriptURL)
        let string = try XCTUnwrap(String(data: data, encoding: .utf8))
        let decoded = try JSONDecoder().decode(TranscriptEvent.self, from: Data(string.dropLast().utf8))
        XCTAssertEqual(decoded, sampleEvent(seq: 42))
    }

    private func temporaryDirectory(file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }

    private func sampleEvent(seq: Int64) -> TranscriptEvent {
        TranscriptEvent(
            seq: seq,
            ts: "2026-04-14T12:01:03.510123Z",
            type: .keyDown,
            keyCode: 0,
            characters: "a",
            charactersIgnoringModifiers: "a",
            modifiers: [],
            isRepeat: false,
            keyboardLayout: nil
        )
    }

}
