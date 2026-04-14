import Foundation

enum WordExtractionError: LocalizedError, Equatable {
    case transcriptNotFound
    case transcriptReadFailed
    case outputWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .transcriptNotFound:
            return "Transcript file not found."
        case .transcriptReadFailed:
            return "Could not read transcript file."
        case let .outputWriteFailed(message):
            return "Could not write extracted words: \(message)"
        }
    }
}

struct WordExtractionService {
    let fileLocations: FileLocations
    let extractor: WordExtractor

    init(fileLocations: FileLocations, extractor: WordExtractor = WordExtractor()) {
        self.fileLocations = fileLocations
        self.extractor = extractor
    }

    func extractInMemory() throws -> WordExtractionResult {
        let transcriptURL = fileLocations.transcriptURL
        guard FileManager.default.fileExists(atPath: transcriptURL.path) else {
            throw WordExtractionError.transcriptNotFound
        }

        let data: Data
        do {
            data = try Data(contentsOf: transcriptURL)
        } catch {
            throw WordExtractionError.transcriptReadFailed
        }

        let events = parseTranscriptEvents(from: data)
        return extractor.extract(from: events)
    }

    func writeToFile(_ result: WordExtractionResult) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let outputData = try encoder.encode(result)

        do {
            try outputData.write(to: fileLocations.extractedWordsURL, options: .atomic)
        } catch {
            throw WordExtractionError.outputWriteFailed(error.localizedDescription)
        }
    }

    func run() throws -> WordExtractionResult {
        let result = try extractInMemory()
        try writeToFile(result)
        return result
    }

    private func parseTranscriptEvents(from data: Data) -> [TranscriptEvent] {
        guard let content = String(data: data, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return content
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                guard let lineData = String(line).data(using: .utf8) else { return nil }
                return try? decoder.decode(TranscriptEvent.self, from: lineData)
            }
    }
}
