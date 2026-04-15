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
    let interpreter: WordInterpreter

    init(
        fileLocations: FileLocations,
        extractionService: WordExtractionService? = nil,
        ranker: WordRanker = WordRanker(),
        interpreter: WordInterpreter = WordInterpreter()
    ) {
        self.fileLocations = fileLocations
        self.extractionService = extractionService
            ?? WordExtractionService(fileLocations: fileLocations)
        self.ranker = ranker
        self.interpreter = interpreter
    }

    func run() throws -> RankedWordResult {
        let extraction = try extractionService.extractInMemory()
        let interpretation = interpreter.interpret(extraction.words)
        let result = ranker.rank(interpretation.words)

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
