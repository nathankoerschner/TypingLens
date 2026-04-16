import Foundation

struct AnalyticsService {
    let fileLocations: FileLocations
    let extractionService: WordExtractionService
    let interpreter: WordInterpreter
    let ranker: WordRanker

    init(
        fileLocations: FileLocations,
        extractionService: WordExtractionService? = nil,
        interpreter: WordInterpreter = WordInterpreter(),
        ranker: WordRanker = WordRanker()
    ) {
        self.fileLocations = fileLocations
        self.extractionService = extractionService ?? WordExtractionService(fileLocations: fileLocations)
        self.interpreter = interpreter
        self.ranker = ranker
    }

    func analyze() throws -> AnalyticsResult {
        let extraction = try extractionService.extractInMemory()
        let interpretation = interpreter.interpret(extraction.words)
        let ranked = ranker.rank(interpretation.words)

        let grouped = Dictionary(grouping: interpretation.words, by: \.normalizedWord)

        let words = ranked.words.enumerated().map { index, rankedWord in
            let occurrences = grouped[rankedWord.word, default: []]
            let totalErrors = occurrences.reduce(0) {
                $0 + $1.transcriptMistakeCount + $1.inferredSpellingPenalty
            }
            let misspellingOccurrences = occurrences.filter(\.wasCorrected)
            let misspellings = Dictionary(grouping: misspellingOccurrences, by: \.originalWord)
                .map { typed, group in
                    MisspellingVariant(
                        id: typed,
                        typed: typed,
                        count: group.count
                    )
                }
                .sorted {
                    if $0.count != $1.count { return $0.count > $1.count }
                    return $0.typed < $1.typed
                }

            return AnalyticsWord(
                id: rankedWord.word,
                rank: index + 1,
                word: rankedWord.word,
                characters: rankedWord.characters,
                frequency: rankedWord.frequency,
                totalErrors: totalErrors,
                misspellingCount: misspellingOccurrences.count,
                avgMsPerChar: rankedWord.avgMsPerChar,
                overallWPM: rankedWord.avgMsPerChar > 0 ? 12_000 / rankedWord.avgMsPerChar : 0,
                compositeScore: rankedWord.compositeScore,
                misspellings: misspellings
            )
        }

        return AnalyticsResult(
            analyzedAt: ranked.analyzedAt,
            totalUniqueWords: ranked.totalUniqueWords,
            words: words
        )
    }
}
