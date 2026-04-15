import Foundation

struct InterpretedWord: Codable, Equatable {
    let originalWord: String
    let normalizedWord: String
    let characters: Int
    let durationMs: Double
    let transcriptMistakeCount: Int
    let inferredSpellingPenalty: Int
    let wasCorrected: Bool
}

enum WordDecision: Equatable {
    case accepted(word: String)
    case corrected(original: String, corrected: String, inferredPenalty: Int)
    case dropped(original: String, reason: DropReason)
}

enum DropReason: String, Codable, Equatable {
    case notInLexicon
    case lowConfidenceCorrection
    case gibberishHeuristic
}

struct WordInterpretationResult: Equatable {
    let words: [InterpretedWord]
    let correctedCount: Int
    let droppedCount: Int
}
