import Foundation

enum RankedExportError: LocalizedError, Equatable {
    case outputWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case let .outputWriteFailed(message):
            return "Could not write ranked words: \(message)"
        }
    }
}

struct RankedExportService {
    let fileLocations: FileLocations
    let extractionService: WordExtractionService
    let ranker: WordRanker

    init(
        fileLocations: FileLocations,
        extractionService: WordExtractionService? = nil,
        ranker: WordRanker = WordRanker()
    ) {
        self.fileLocations = fileLocations
        self.extractionService = extractionService
            ?? WordExtractionService(fileLocations: fileLocations)
        self.ranker = ranker
    }

    func run() throws -> RankedWordResult {
        let extraction = try extractionService.extractInMemory()
        let result = ranker.rank(extraction.words)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let outputData = try encoder.encode(result)

        do {
            try outputData.write(to: fileLocations.rankedWordsURL, options: .atomic)
        } catch {
            throw RankedExportError.outputWriteFailed(error.localizedDescription)
        }

        return result
    }
}
