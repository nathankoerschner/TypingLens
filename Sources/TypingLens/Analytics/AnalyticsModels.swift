import Foundation

struct AnalyticsResult: Equatable, Codable {
    let analyzedAt: String
    let totalUniqueWords: Int
    let words: [AnalyticsWord]
}

struct AnalyticsWord: Equatable, Codable, Identifiable {
    let id: String
    let rank: Int
    let word: String
    let characters: Int
    let frequency: Int
    let totalErrors: Int
    let misspellingCount: Int
    let avgMsPerChar: Double
    let overallWPM: Double
    let compositeScore: Double
    let misspellings: [MisspellingVariant]
}

struct MisspellingVariant: Equatable, Codable, Identifiable {
    let id: String
    let typed: String
    let count: Int
}
