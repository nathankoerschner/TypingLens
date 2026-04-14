import AppKit
import Foundation

protocol TranscriptWriting {
    func initializeNextSequence() throws -> Int64
    func append(_ event: TranscriptEvent) throws
    func clearTranscript() throws
    func revealInFinder()
}

enum TranscriptWriterError: LocalizedError, Equatable {
    case failedToCreateDirectory
    case failedToCreateTranscript
    case invalidTailRecord
    case appendFailed(String)

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory:
            return "Could not create the TypingLens application support directory."
        case .failedToCreateTranscript:
            return "Could not create transcript.jsonl."
        case .invalidTailRecord:
            return "The existing transcript tail could not be parsed."
        case let .appendFailed(message):
            return "Transcript append failed: \(message)"
        }
    }
}

final class TranscriptWriter: TranscriptWriting {
    private let fileLocations: FileLocations
    private let fileManager: FileManager
    private let encoder = JSONEncoder.transcriptEncoder()

    init(
        fileLocations: FileLocations,
        fileManager: FileManager = .default
    ) {
        self.fileLocations = fileLocations
        self.fileManager = fileManager
    }

    func initializeNextSequence() throws -> Int64 {
        try ensureTranscriptExists()
        guard let lastLine = try readLastNonEmptyLine() else {
            return 1
        }

        struct TailRecord: Decodable {
            let seq: Int64
        }

        guard let data = lastLine.data(using: .utf8) else {
            throw TranscriptWriterError.invalidTailRecord
        }

        do {
            let record = try JSONDecoder().decode(TailRecord.self, from: data)
            return record.seq + 1
        } catch {
            throw TranscriptWriterError.invalidTailRecord
        }
    }

    func append(_ event: TranscriptEvent) throws {
        let data = try encoder.encode(event) + Data("\n".utf8)

        do {
            try appendData(data)
        } catch {
            if shouldAttemptTranscriptRecreation(from: error) {
                try appendData(data)
                return
            }
            throw TranscriptWriterError.appendFailed(error.localizedDescription)
        }
    }

    func clearTranscript() throws {
        try ensureTranscriptExists()
        do {
            try Data().write(to: fileLocations.transcriptURL, options: .atomic)
        } catch {
            throw TranscriptWriterError.appendFailed(error.localizedDescription)
        }
    }

    func revealInFinder() {
        let urlToReveal: URL
        if fileManager.fileExists(atPath: fileLocations.transcriptURL.path) {
            urlToReveal = fileLocations.transcriptURL
        } else {
            urlToReveal = fileLocations.appDirectoryURL
        }
        NSWorkspace.shared.activateFileViewerSelecting([urlToReveal])
    }

    private func appendData(_ data: Data) throws {
        do {
            try ensureTranscriptExists()
            let handle = try FileHandle(forWritingTo: fileLocations.transcriptURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            throw error
        }
    }

    private func shouldAttemptTranscriptRecreation(from error: Error) -> Bool {
        guard let nsError = error as NSError? else {
            return false
        }
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError
    }

    private func ensureTranscriptExists() throws {
        do {
            try fileManager.createDirectory(
                at: fileLocations.appDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw TranscriptWriterError.failedToCreateDirectory
        }

        if !fileManager.fileExists(atPath: fileLocations.transcriptURL.path) {
            let created = fileManager.createFile(atPath: fileLocations.transcriptURL.path, contents: nil)
            if !created {
                throw TranscriptWriterError.failedToCreateTranscript
            }
        }
    }

    private func readLastNonEmptyLine() throws -> String? {
        let url = fileLocations.transcriptURL
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let fileSize = try handle.seekToEnd()
        guard fileSize > 0 else { return nil }

        let chunkSize = 4096
        var remainingOffset = fileSize
        var buffer = Data()

        while remainingOffset > 0 {
            let readSize = min(UInt64(chunkSize), remainingOffset)
            remainingOffset -= readSize
            try handle.seek(toOffset: remainingOffset)
            let chunk = try handle.read(upToCount: Int(readSize)) ?? Data()
            buffer.insert(contentsOf: chunk, at: 0)

            let newlineCount = buffer.reduce(into: 0) { count, byte in
                if byte == 0x0A { count += 1 }
            }

            if newlineCount >= 2 || (remainingOffset == 0 && newlineCount >= 1) {
                break
            }
        }

        guard let content = String(data: buffer, encoding: .utf8) else { return nil }
        let lines = content.split(omittingEmptySubsequences: true, whereSeparator: { $0.isNewline })
        return String(lines.last ?? "")
    }
}
