import Foundation

struct RankedWord: Codable, Equatable {
    let word: String
    let characters: Int
    let frequency: Int
    let avgMsPerChar: Double
    let errorRate: Double
    let compositeScore: Double
}

struct RankedWordResult: Codable, Equatable {
    let analyzedAt: String
    let totalUniqueWords: Int
    let words: [RankedWord]
}
