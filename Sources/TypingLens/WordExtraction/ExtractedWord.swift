import Foundation

struct ExtractedWord: Codable, Equatable {
    let word: String
    let characters: Int
    let durationMs: Double
    let mistakeCount: Int
}

struct WordExtractionResult: Codable, Equatable {
    let extractedAt: String
    let totalWords: Int
    let words: [ExtractedWord]
}
